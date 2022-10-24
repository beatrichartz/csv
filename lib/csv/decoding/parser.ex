defmodule CSV.Decoding.Parser do
  use CSV.Defaults

  @moduledoc ~S"""
  The Parser CSV module transforms a stream of byte chunks or bytes
  into a stream of row tuples and (potentially) error tuples. It
  follows the grammar defined in [RFC4180](https://www.rfc-editor.org/rfc/rfc4180).
  """
  alias CSV.StrayQuoteError
  alias CSV.EscapeSequenceError

  @doc """
  Parse a stream of comma-separated lines into a stream of rows.
  The Parser expects line or variable size byte stream input.

  ## Options

  These are the options:

  * `:separator`           – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
  * `:field_transform`     – A function with arity 1 that will get called with 
      each field and can apply transformations. Defaults to identity function.
      This function will get called for every field and therefore should return 
      quickly.
  * `:unescape_formulas    – When set to `true`, will remove formula escaping 
      inserted to prevent [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

  ## Examples

  Convert a stream of lines with inlined escape sequences into a stream of rows:

      iex> [\"a,b\\n\",\"c,d\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Parser.parse
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  Convert a stream of lines with into a stream of rows trimming each field:

      iex> [\" a , b   \\n\",\" c   ,   d \\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Parser.parse(field_transform: &String.trim/1)
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  """
  @type parse_options ::
          {:unescape_formulas, boolean()}
          | {:separator, char}
          | {:field_transform, (String.t() -> String.t())}

  @spec parse(Enumerable.t(), [parse_options()]) :: Enumerable.t()
  def parse(stream, options \\ []) do
    stream
    |> parse_into_rows(options)
  end

  defp parse_into_rows(stream, options) do
    escape_max_lines = get_escape_max_lines(options)

    token_pattern = create_token_pattern(options)
    field_transform = create_field_transform(options)

    stream
    |> Stream.concat([:stream_halted])
    |> Stream.transform(
      fn -> {[], "", {:open, 0, 1}, ""} end,
      create_row_transform(escape_max_lines, token_pattern, field_transform),
      fn _ -> :ok end
    )
  end

  defp empty_state do
    {[], {[], "", {:open, 0, 1}, ""}}
  end

  defp create_unescape_formulas(options) do
    unescape_formulas = options |> Keyword.get(:unescape_formulas, @unescape_formulas)

    if unescape_formulas do
      formula_pattern = :binary.compile_pattern(@escape_formula_start)

      fn field ->
        case :binary.match(field, formula_pattern) do
          {1, _} -> binary_part(field, 1, byte_size(field) - 1)
          _ -> field
        end
      end
    else
      fn field -> field end
    end
  end

  defp get_user_transform(options) do
    options
    |> Keyword.get(
      :field_transform,
      fn field -> field end
    )
  end

  defp create_field_transform(options) do
    unescape_formulas_fn = create_unescape_formulas(options)
    user_transform_fn = get_user_transform(options)

    fn
      line, "", {field_start_position, length} ->
        :binary.copy(
          user_transform_fn.(
            unescape_formulas_fn.(binary_part(line, field_start_position, length))
          )
        )

      line, partial_field, {field_start_position, length} ->
        :binary.copy(
          user_transform_fn.(
            unescape_formulas_fn.(
              partial_field <> binary_part(line, field_start_position, length)
            )
          )
        )
    end
  end

  defp create_token_pattern(options) do
    separator = get_separator(options)

    :binary.compile_pattern([
      separator,
      @escape,
      @carriage_return,
      @newline
    ])
  end

  defp get_separator(options) do
    <<options |> Keyword.get(:separator, @separator)::utf8>>
  end

  defp get_escape_max_lines(options) do
    options |> Keyword.get(:escape_max_lines, @escape_max_lines)
  end

  @compile {:inline, create_row_transform: 3}
  defp create_row_transform(escape_max_lines, token_pattern, field_transform) do
    fn
      :stream_halted, {[], _, _, ""} ->
        empty_state()

      :stream_halted, end_state ->
        {fields, partial_field, parse_state, sequence} =
          case end_state do
            {_, _, _, _} = state ->
              state

            {fields, partial_field, parse_state, sequence, _} ->
              {fields, partial_field, parse_state, sequence}
          end

        parse_to_end(
          {[], {fields, partial_field, parse_state, sequence}},
          token_pattern,
          field_transform
        )

      sequence, {fields, partial_field, parse_state, leftover_sequence, :reparse} ->
        full_sequence = leftover_sequence <> sequence

        parse_byte_sequence(
          full_sequence,
          [],
          {fields, partial_field, parse_state},
          :binary.matches(full_sequence, token_pattern),
          escape_max_lines,
          field_transform
        )

      sequence, {fields, partial_field, parse_state, leftover_sequence} ->
        full_sequence = leftover_sequence <> sequence

        parse_byte_sequence(
          full_sequence,
          [],
          {fields, partial_field, parse_state},
          :binary.matches(full_sequence, token_pattern,
            scope: {byte_size(leftover_sequence), byte_size(sequence)}
          ),
          escape_max_lines,
          field_transform
        )
    end
  end

  defp parse_to_end({rows, {[], _, _, ""} = parse_state}, _, _) do
    {rows |> add_stream_halted_to_errors, parse_state}
  end

  defp parse_to_end(
         {rows, {fields, partial_field, {:open, _, _} = parse_state, sequence}},
         token_pattern,
         field_transform
       ) do
    tokens = :binary.matches(sequence, token_pattern)

    case tokens do
      [] ->
        {(rows ++
            [
              {:ok,
               fields ++ [field_transform.(sequence, partial_field, {0, byte_size(sequence)})]}
            ])
         |> add_stream_halted_to_errors, {[], "", {:open, 0, 1}, ""}}

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          :binary.matches(sequence, @newline) |> Enum.count(),
          field_transform
        )
        |> parse_to_end(token_pattern, field_transform)
    end
  end

  defp parse_to_end(
         {rows,
          {fields, partial_field, {:escape_closing, previous_token_position, _, _, _}, sequence}},
         _,
         _
       ) do
    case byte_size(sequence) - 1 do
      ^previous_token_position ->
        {(rows ++ [ok: fields ++ [partial_field]]) |> add_stream_halted_to_errors,
         {[], "", {:open, 0, 1}, ""}}

      _ ->
        {rows, {[], "", {:open, 0, 1}, ""}}
    end
  end

  defp parse_to_end(
         {rows, {fields, partial_field, {:escaped, _, _, _} = parse_state, sequence}},
         token_pattern,
         field_transform
       ) do
    tokens = :binary.matches(sequence, token_pattern)

    case tokens do
      [] ->
        {rows, {[], "", {:open, 0, 1}, ""}}

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          :binary.matches(sequence, @newline) |> Enum.count(),
          field_transform
        )
        |> parse_to_end(token_pattern, field_transform)
    end
  end

  defp parse_to_end(
         {rows, {[], _, {:errored, _, error_module, construct_arguments, _}, _}},
         _,
         _
       ) do
    {(rows ++ [{:error, error_module, construct_arguments.(:none)}])
     |> add_stream_halted_to_errors, {[], "", {:open, 0, 1}, ""}}
  end

  defp parse_to_end(
         {rows, {fields, partial_field, parse_state, sequence, _}},
         token_pattern,
         field_transform
       ) do
    parse_to_end(
      {rows, {fields, partial_field, parse_state, sequence}},
      token_pattern,
      field_transform
    )
  end

  defp add_stream_halted_to_errors(rows) do
    rows
    |> Enum.map(fn
      {:ok, _} = row ->
        row

      {:error, error_module, arguments} ->
        {:error, error_module, arguments |> Keyword.merge(stream_halted: true)}
    end)
  end

  @compile {:inline, parse_byte_sequence: 6}
  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:open, field_start_position, line}},
         [{token_position, token_length} | tokens],
         escape_max_lines,
         finalize_field
       ) do
    case binary_part(sequence, token_position, token_length) do
      @escape when field_start_position == token_position ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, token_position + token_length, line, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @escape ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], "",
           {:errored, field_start_position, StrayQuoteError,
            fn s ->
              [
                line: line,
                sequence_position: token_position + token_length,
                sequence:
                  case s do
                    :none -> sequence
                    _ -> s
                  end
              ]
            end, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @newline ->
        new_field =
          finalize_field.(
            sequence,
            partial_field,
            {field_start_position, token_position - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows ++ [{:ok, fields ++ [new_field]}],
          {[], "", {:open, token_position + token_length, line + 1}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @carriage_return ->
        new_field =
          finalize_field.(
            sequence,
            partial_field,
            {field_start_position, token_position - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows ++ [{:ok, fields ++ [new_field]}],
          {[], "", {:row_closing, token_position + token_length, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      _ ->
        new_field =
          finalize_field.(
            sequence,
            partial_field,
            {field_start_position, token_position - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows,
          {fields ++ [new_field], "", {:open, token_position + token_length, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
         [{token_position, token_length} | tokens],
         escape_max_lines,
         finalize_field
       ) do
    case binary_part(sequence, token_position, token_length) do
      @escape ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field,
           {:escape_closing, token_position, field_start_position, escape_start_line, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @newline when escape_start_line + escape_max_lines == line ->
        {first_line_end, _} = :binary.match(sequence, [@newline])

        leftover_sequence =
          binary_part(sequence, first_line_end + 1, byte_size(sequence) - (first_line_end + 1))

        {rows ++
           [
             {:error, EscapeSequenceError,
              [
                line: escape_start_line,
                escape_max_lines: escape_max_lines,
                escape_sequence_start:
                  :binary.replace(partial_field, [@escape], @escape <> @escape, [:global]) <>
                    @escape <>
                    binary_part(
                      sequence,
                      field_start_position,
                      first_line_end - field_start_position
                    )
              ]}
           ], {[], "", {:open, 0, escape_start_line + 1}, leftover_sequence, :reparse}}

      @newline ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, field_start_position, escape_start_line, line + 1}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @carriage_return ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field,
          {:escape_closing, previous_token_position, field_start_position, escape_start_line,
           line}},
         [{token_position, token_length} | tokens],
         escape_max_lines,
         finalize_field
       ) do
    case binary_part(sequence, token_position, token_length) do
      _ when previous_token_position + 1 != token_position ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], partial_field,
           {:errored, field_start_position, StrayQuoteError,
            fn sequence ->
              [
                line: line,
                sequence_position: previous_token_position + 2 - field_start_position,
                sequence: @escape <> sequence
              ]
            end, escape_start_line}},
          [{token_position, token_length} | tokens],
          escape_max_lines,
          finalize_field
        )

      @escape when previous_token_position + 1 == token_position ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields,
           finalize_field.(
             sequence,
             partial_field,
             {field_start_position, token_position - field_start_position}
           ), {:escaped, token_position + token_length, escape_start_line, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @carriage_return ->
        new_field =
          finalize_field.(
            sequence,
            partial_field,
            {field_start_position, token_position - token_length - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows ++ [{:ok, fields ++ [new_field]}],
          {[], "", {:row_closing, token_position + token_length, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      @newline ->
        new_field =
          finalize_field.(
            sequence,
            partial_field,
            {field_start_position, token_position - token_length - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows ++ [{:ok, fields ++ [new_field]}],
          {[], "", {:open, token_position + token_length, line + 1}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      _ ->
        new_field =
          finalize_field.(
            sequence,
            partial_field,
            {field_start_position, token_position - token_length - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows,
          {fields ++ [new_field], "", {:open, token_position + token_length, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {_, _, {:errored, field_start_position, error_module, construct_arguments, line}},
         [{token_position, token_length} | tokens],
         escape_max_lines,
         finalize_field
       ) do
    case binary_part(sequence, token_position, token_length) do
      @newline ->
        {first_newline_position, _} = :binary.match(sequence, @newline)

        leftover_sequence =
          binary_part(
            sequence,
            first_newline_position + 1,
            byte_size(sequence) - (first_newline_position + 1)
          )

        {rows ++
           [
             {:error, error_module,
              construct_arguments.(
                binary_part(sequence, field_start_position, token_position - field_start_position)
              )}
           ], {[], "", {:open, 0, line + 1}, leftover_sequence, :reparse}}

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], "", {:errored, field_start_position, error_module, construct_arguments, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:row_closing, _, line}},
         [{token_position, token_length} | tokens],
         escape_max_lines,
         finalize_field
       ) do
    case binary_part(sequence, token_position, token_length) do
      @newline ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:open, token_position + token_length, line + 1}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:open, 0, line}},
          [{token_position, token_length} | tokens],
          escape_max_lines,
          finalize_field
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
         [],
         _,
         _
       ) do
    leftover_sequence =
      binary_part(sequence, field_start_position, byte_size(sequence) - field_start_position)

    {rows, {fields, partial_field, {:escaped, 0, escape_start_line, line}, leftover_sequence}}
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {_, _, {:errored, field_start_position, error_module, construct_arguments, line}},
         [],
         _,
         _
       ) do
    leftover_sequence =
      binary_part(sequence, field_start_position, byte_size(sequence) - field_start_position)

    {rows, {[], "", {:errored, 0, error_module, construct_arguments, line}, leftover_sequence}}
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field,
          {:escape_closing, previous_token_position, field_start_position, escape_start_line,
           line}},
         [],
         _,
         _
       ) do
    {rows,
     {fields, partial_field,
      {:escape_closing, previous_token_position, field_start_position, escape_start_line, line},
      sequence}}
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {current_parse_state, field_start_position, line}},
         [],
         _,
         _
       ) do
    leftover_sequence =
      binary_part(sequence, field_start_position, byte_size(sequence) - field_start_position)

    {rows, {fields, partial_field, {current_parse_state, 0, line}, leftover_sequence}}
  end
end
