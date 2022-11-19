defmodule CSV.Decoding.Parser do
  use CSV.Defaults

  @moduledoc ~S"""
  The Parser CSV module transforms a stream of byte chunks or bytes
  into a stream of row tuples and (potentially) error tuples. It
  follows the grammar defined in [RFC4180](https://www.rfc-editor.org/rfc/rfc4180).
  """
  alias CSV.StrayEscapeCharacterError
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
  * `:unescape_formulas`   – When set to `true`, will remove formula escaping 
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
          | {:escape_max_lines, integer()}
          | {:separator, char}
          | {:escape_character, char}
          | {:field_transform, (String.t() -> String.t())}

  @spec parse(Enumerable.t(), [parse_options()]) :: Enumerable.t()
  def parse(stream, options \\ []) do
    stream
    |> parse_into_rows(options)
  end

  defp parse_into_rows(stream, options) do
    escape_max_lines = get_escape_max_lines(options)

    escape = get_escape(options)
    token_pattern = create_token_pattern(options)
    field_transform = create_field_transform(options)

    stream
    |> Stream.concat([:stream_halted])
    |> Stream.transform(
      &empty_transform_state/0,
      create_row_transform({escape, escape_max_lines}, token_pattern, field_transform),
      fn _ -> :ok end
    )
  end

  @compile {:inline, empty_transform_state: 0}
  defp empty_transform_state do
    {[], "", {:open, 0, 1}, {:parsed, ""}}
  end

  @compile {:inline, new_rows_transform_state: 2}
  defp new_rows_transform_state(parser_state, leftover) do
    {[], "", parser_state, leftover}
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
    escape = get_escape(options)

    :binary.compile_pattern([
      separator,
      escape,
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

  defp get_escape(options) do
    <<options |> Keyword.get(:escape_character, @escape_character)::utf8>>
  end

  defp create_row_transform(
         {escape_character, _} = escape,
         token_pattern,
         field_transform
       ) do
    fn
      :stream_halted, {fields, partial_field, parse_state, sequence} ->
        parse_to_end(
          {[], {fields, partial_field, parse_state, sequence}},
          escape_character,
          token_pattern,
          field_transform
        )

      sequence, {fields, partial_field, parse_state, {leftover_state, leftover_sequence}} ->
        full_sequence = leftover_sequence <> sequence

        matches_arguments =
          case leftover_state do
            :parsed -> [scope: {byte_size(leftover_sequence), byte_size(sequence)}]
            :unparsed -> []
          end

        parse_byte_sequence(
          full_sequence,
          [],
          {fields, partial_field, parse_state},
          :binary.matches(full_sequence, token_pattern, matches_arguments),
          escape,
          field_transform
        )
    end
  end

  @compile {:inline, parse_to_end: 4}
  defp parse_to_end({rows, {[], _, _, {_, ""}} = parse_state}, _, _, _) do
    {rows |> add_stream_halted_to_errors, parse_state}
  end

  defp parse_to_end(
         {rows, {fields, partial_field, {:open, _, _} = parse_state, {_, sequence}}},
         escape_character,
         token_pattern,
         field_transform
       ) do
    tokens = :binary.matches(sequence, token_pattern)

    case tokens do
      [] ->
        new_field = field_transform.(sequence, partial_field, {0, byte_size(sequence)})

        {rows
         |> add_row(fields ++ [new_field])
         |> add_stream_halted_to_errors, empty_transform_state()}

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          {escape_character, :binary.matches(sequence, @newline) |> Enum.count()},
          field_transform
        )
        |> parse_to_end(escape_character, token_pattern, field_transform)
    end
  end

  defp parse_to_end(
         {rows,
          {fields, partial_field,
           {:escape_closing, previous_token_position, field_start_position, _, line},
           {_, sequence}}},
         _,
         _,
         field_transform
       ) do
    case byte_size(sequence) - 1 do
      ^previous_token_position ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, byte_size(sequence) - 1 - field_start_position}
          )

        {rows |> add_row(fields ++ [new_field]) |> add_stream_halted_to_errors,
         empty_transform_state()}

      _ ->
        {rows
         |> add_error(StrayEscapeCharacterError,
           line: line,
           sequence: sequence,
           stream_halted: true
         ), empty_transform_state()}
    end
  end

  defp parse_to_end(
         {rows, {fields, partial_field, {:escaped, _, _, line} = parse_state, {_, sequence}}},
         escape_character,
         token_pattern,
         field_transform
       ) do
    tokens = :binary.matches(sequence, token_pattern)

    case tokens do
      [] ->
        {rows
         |> add_error(EscapeSequenceError,
           line: line,
           escape_sequence_start:
             escape_character <>
               :binary.replace(
                 partial_field,
                 escape_character,
                 escape_character <> escape_character
               ) <> sequence,
           stream_halted: true
         ), empty_transform_state()}

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          {escape_character, :binary.matches(sequence, @newline) |> Enum.count()},
          field_transform
        )
        |> parse_to_end(escape_character, token_pattern, field_transform)
    end
  end

  defp parse_to_end(
         {rows, {[], _, {:errored, _, error_module, construct_arguments, _}, _}},
         _,
         _,
         _
       ) do
    {rows
     |> add_error(error_module, construct_arguments.([]))
     |> add_stream_halted_to_errors, empty_transform_state()}
  end

  @compile {:inline, add_row: 2}
  def add_row(rows, row) do
    rows ++
      [
        {:ok, row}
      ]
  end

  @compile {:inline, add_error: 3}
  def add_error(rows, error_module, arguments) do
    rows ++
      [
        {:error, error_module, arguments}
      ]
  end

  @compile {:inline, add_stream_halted_to_errors: 1}
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
         {escape, escape_max_lines},
         field_transform
       ) do
    case binary_part(sequence, token_position, token_length) do
      ^escape when field_start_position == token_position ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, token_position + token_length, line, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      ^escape ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], "",
           {:errored, field_start_position, StrayEscapeCharacterError,
            fn arguments ->
              [
                line: line,
                sequence: sequence
              ]
              |> Keyword.merge(arguments)
            end, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      @newline ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, token_position - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows |> add_row(fields ++ [new_field]),
          {[], "", {:open, token_position + token_length, line + 1}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      @carriage_return ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, token_position - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows |> add_row(fields ++ [new_field]),
          {[], "", {:row_closing, token_position + token_length, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      _ ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, token_position - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows,
          {fields ++ [new_field], "", {:open, token_position + token_length, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
         [{token_position, token_length} | tokens],
         {escape, escape_max_lines},
         field_transform
       ) do
    case binary_part(sequence, token_position, token_length) do
      ^escape ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field,
           {:escape_closing, token_position, field_start_position, escape_start_line, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      @newline when escape_start_line + escape_max_lines == line ->
        {first_line_end, _} = :binary.match(sequence, [@newline])

        leftover_sequence =
          binary_part(sequence, first_line_end + 1, byte_size(sequence) - (first_line_end + 1))

        {rows
         |> add_error(EscapeSequenceError,
           line: escape_start_line,
           escape_max_lines: escape_max_lines,
           escape_sequence_start:
             :binary.replace(partial_field, [escape], escape <> escape, [:global]) <>
               escape <>
               binary_part(
                 sequence,
                 field_start_position,
                 first_line_end - field_start_position
               )
         ),
         new_rows_transform_state(
           {:open, 0, escape_start_line + 1},
           {:unparsed, leftover_sequence}
         )}

      @newline ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, field_start_position, escape_start_line, line + 1}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      @carriage_return ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:escaped, field_start_position, escape_start_line, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
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
         {escape, escape_max_lines},
         field_transform
       ) do
    case binary_part(sequence, token_position, token_length) do
      _ when previous_token_position + 1 != token_position ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], partial_field,
           {:errored, field_start_position, StrayEscapeCharacterError,
            fn arguments ->
              [
                line: line,
                sequence: escape <> Keyword.get(arguments, :sequence, sequence)
              ]
            end, escape_start_line}},
          [{token_position, token_length} | tokens],
          {escape, escape_max_lines},
          field_transform
        )

      ^escape when previous_token_position + 1 == token_position ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields,
           field_transform.(
             sequence,
             partial_field,
             {field_start_position, token_position - field_start_position}
           ), {:escaped, token_position + token_length, escape_start_line, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      @carriage_return ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, token_position - token_length - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows |> add_row(fields ++ [new_field]),
          {[], "", {:row_closing, token_position + token_length, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      @newline ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, token_position - token_length - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows |> add_row(fields ++ [new_field]),
          {[], "", {:open, token_position + token_length, line + 1}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      _ ->
        new_field =
          field_transform.(
            sequence,
            partial_field,
            {field_start_position, token_position - token_length - field_start_position}
          )

        parse_byte_sequence(
          sequence,
          rows,
          {fields ++ [new_field], "", {:open, token_position + token_length, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {_, _, {:errored, field_start_position, error_module, construct_arguments, line}},
         [{token_position, token_length} | tokens],
         {escape, escape_max_lines},
         field_transform
       ) do
    case binary_part(sequence, token_position, token_length) do
      @newline ->
        {first_newline_position, _} =
          :binary.match(sequence, @newline,
            scope: {field_start_position, byte_size(sequence) - field_start_position}
          )

        leftover_sequence =
          binary_part(
            sequence,
            first_newline_position + 1,
            byte_size(sequence) - (first_newline_position + 1)
          )

        {rows
         |> add_error(
           error_module,
           construct_arguments.(
             sequence:
               binary_part(
                 sequence,
                 field_start_position,
                 token_position - field_start_position
               )
           )
         ), new_rows_transform_state({:open, 0, line + 1}, {:unparsed, leftover_sequence})}

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], "", {:errored, field_start_position, error_module, construct_arguments, line}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:row_closing, _, line}},
         [{token_position, token_length} | tokens],
         {escape, escape_max_lines},
         field_transform
       ) do
    case binary_part(sequence, token_position, token_length) do
      @newline ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:open, token_position + token_length, line + 1}},
          tokens,
          {escape, escape_max_lines},
          field_transform
        )

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, {:open, 0, line}},
          [{token_position, token_length} | tokens],
          {escape, escape_max_lines},
          field_transform
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

    {rows,
     {fields, partial_field, {:escaped, 0, escape_start_line, line}, {:parsed, leftover_sequence}}}
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

    {rows,
     new_rows_transform_state(
       {:errored, 0, error_module, construct_arguments, line},
       {:parsed, leftover_sequence}
     )}
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
      {:parsed, sequence}}}
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

    {rows, {fields, partial_field, {current_parse_state, 0, line}, {:parsed, leftover_sequence}}}
  end
end
