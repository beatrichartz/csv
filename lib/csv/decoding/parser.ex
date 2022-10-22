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
    |> Stream.concat([:stream_halted, :finish_parsing])
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

  defp get_user_finalizer(options) do
    options
    |> Keyword.get(
      :field_transform,
      fn field -> field end
    )
  end

  defp create_field_transform(options) do
    unescape_formulas_fn = create_unescape_formulas(options)
    user_finalizer_fn = get_user_finalizer(options)

    fn
      line, "", {field_start_position, length} ->
        :binary.copy(
          user_finalizer_fn.(
            unescape_formulas_fn.(binary_part(line, field_start_position, length))
          )
        )

      line, partial_field, {field_start_position, length} ->
        :binary.copy(
          user_finalizer_fn.(
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

      :stream_halted, {fields, partial_field, parse_state, sequence} ->
        rows = []
        tokens = :binary.matches(sequence, token_pattern)

        parse_byte_sequence(
          sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          :stream_halted,
          field_transform
        )

      :finish_parsing, {[], "", _, _} ->
        empty_state()

      :finish_parsing, {fields, "", _, ""} ->
        {[{:ok, fields}], {[], "", {:open, 0, 1}, ""}}

      :finish_parsing, {fields, partial_field, _, last_field} ->
        {[{:ok, fields ++ [partial_field <> last_field]}], {[], "", {:open, 0, 1}, ""}}

      :finish_parsing, {fields, partial_field, parse_state, sequence, :reparse} ->
        full_sequence = sequence
        rows = []
        tokens = :binary.matches(full_sequence, token_pattern)

        parse_byte_sequence(
          full_sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          :stream_halted,
          field_transform
        )

      sequence, {fields, partial_field, parse_state, leftover_sequence, :reparse} ->
        full_sequence = leftover_sequence <> sequence
        rows = []

        tokens = :binary.matches(full_sequence, token_pattern)

        parse_byte_sequence(
          full_sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          escape_max_lines,
          field_transform
        )

      sequence, {fields, partial_field, parse_state, leftover_sequence} ->
        full_sequence = leftover_sequence <> sequence
        rows = []

        tokens =
          :binary.matches(full_sequence, token_pattern,
            scope: {byte_size(leftover_sequence), byte_size(sequence)}
          )

        parse_byte_sequence(
          full_sequence,
          rows,
          {fields, partial_field, parse_state},
          tokens,
          escape_max_lines,
          field_transform
        )
    end
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
            [
              line: line,
              sequence_position: token_position + token_length,
              sequence: sequence
            ], line}},
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

      @newline when escape_max_lines == :stream_halted ->
        {first_line_end, _} = :binary.match(sequence, [@newline])

        leftover_sequence =
          binary_part(sequence, first_line_end + 1, byte_size(sequence) - (first_line_end + 1))

        {rows ++
           [
             {:error, EscapeSequenceError,
              [
                line: escape_start_line,
                stream_halted: true,
                escape_sequence_start:
                  :binary.replace(partial_field, [@escape], @escape <> @escape, [:global]) <>
                    @escape <>
                    binary_part(sequence, 0, first_line_end)
              ]}
           ], {[], "", {:open, 0, escape_start_line + 1}, leftover_sequence, :reparse}}

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
                  partial_field <> @escape <> binary_part(sequence, 0, first_line_end)
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
        sequence_for_error =
          @escape <>
            case :binary.match(sequence, @newline,
                   scope: {field_start_position, byte_size(sequence) - field_start_position}
                 ) do
              {newline_position, _} ->
                binary_part(
                  sequence,
                  field_start_position,
                  newline_position - field_start_position
                )

              :nomatch ->
                binary_part(
                  sequence,
                  field_start_position,
                  byte_size(sequence) - field_start_position
                )
            end

        parse_byte_sequence(
          sequence,
          rows,
          {[], "",
           {:errored, field_start_position, StrayQuoteError,
            [
              line: line,
              sequence_position: previous_token_position + 2 - field_start_position,
              sequence: sequence_for_error
            ], line}},
          tokens,
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
            {field_start_position, token_position - 1 - field_start_position}
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
         {_, _, {:errored, field_start_position, error_module, arguments, line}},
         [{token_position, token_length} | tokens],
         escape_max_lines,
         finalize_field
       ) do
    case binary_part(sequence, token_position, token_length) do
      @newline ->
        leftover_sequence =
          binary_part(sequence, token_position + 1, byte_size(sequence) - (token_position + 1))

        {rows ++ [{:error, error_module, arguments}],
         {[], "", {:open, 0, line + 1}, leftover_sequence}}

      _ when escape_max_lines == :stream_halted ->
        parse_byte_sequence(
          sequence,
          rows ++ [{:error, error_module, arguments}],
          {[], "", {:open, 0, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )

      _ ->
        parse_byte_sequence(
          sequence,
          rows,
          {[], "", {:errored, field_start_position, error_module, arguments, line}},
          tokens,
          escape_max_lines,
          finalize_field
        )
    end
  end

  defp parse_byte_sequence(
         sequence,
         rows,
         {fields, partial_field, {:row_closing, field_start_position, line}},
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
          {fields, partial_field, {:open, field_start_position, line}},
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
         {_, _, {:errored, field_start_position, error_module, arguments, line}},
         [],
         _,
         _
       ) do
    leftover_sequence =
      binary_part(sequence, field_start_position, byte_size(sequence) - field_start_position)

    {rows, {[], "", {:errored, 0, error_module, arguments, line}, leftover_sequence}}
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
