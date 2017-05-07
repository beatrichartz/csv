defmodule CSV.Decoding.Preprocessing.Lines do
  use CSV.Defaults

  alias CSV.EscapeSequenceError

  @moduledoc ~S"""
  The CSV lines preprocessor module - aggregates lines in a stream that are part
  of a common escape sequence.
  """

  @doc """
  Aggregates the common escape sequences of a stream with the given separator.

  ## Options

  Options get transferred from the decoder. They are:

    * `:separator` – The field separator
    * `:escape_max_lines` – The maximum number of lines to collect in an escaped field
  """

def process(stream, options \\ []) do
    separator = options |> Keyword.get(:separator, @separator)
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream |>
    Stream.with_index |>
    Stream.transform(fn -> { [], "", 0, 0 } end, fn
      { line, line_index }, { [], _, _, _ } ->
        start_sequence(line, line_index, separator)
      { line, line_index }, { escaped_lines, sequence_start, sequence_start_index, num_escaped_lines } when num_escaped_lines < escape_max_lines ->
        continue_sequence(escaped_lines, num_escaped_lines + 1, line, line_index, separator, sequence_start, sequence_start_index)
      { _, line_index }, { _, sequence_start, _, num_escaped_lines } ->
          raise EscapeSequenceError,
            line: line_index + 1,
            escape_sequence: sequence_start,
            escape_max_lines: escape_max_lines,
            num_escaped_lines: num_escaped_lines
    end, fn
      { [], _, _, _ } ->
        :ok
      { _, sequence_start, sequence_start_index, num_escaped_lines } ->
        raise EscapeSequenceError,
          line: sequence_start_index + 1,
          escape_sequence: sequence_start,
          escape_max_lines: escape_max_lines,
          num_escaped_lines: num_escaped_lines
    end)
  end
  defp start_sequence(line, line_index, separator) do
    { starts_sequence, sequence_start } = starts_sequence?(line, separator)
    cond do
      starts_sequence ->
        { [], { [line], sequence_start, line_index, 1 } }
      true ->
        { [line], { [], "", 0, 0 } }
    end
  end
  defp continue_sequence(escaped_lines, num_escaped_lines, line, line_index, separator, sequence_start, sequence_start_index) do
    { ends_sequence, _ } = ends_sequence?(line, separator)
    cond do
      ends_sequence ->
        start_sequence(escaped_lines ++ [line] |> Enum.join(@delimiter), line_index, separator)
      true ->
        { [], { escaped_lines ++ [line], sequence_start <> @delimiter <> line, sequence_start_index, num_escaped_lines } }
    end
  end

  defp ends_sequence?(line, separator) do
    ends_sequence?(line, "", true, separator)
  end

  defp ends_sequence?(<< @double_quote :: utf8 >> <> tail, _, quoted, separator) do
    ends_sequence?(tail, << @double_quote :: utf8 >>, !quoted, separator)
  end
  defp ends_sequence?(<< head :: utf8 >> <> tail, _, quoted, separator) do
    ends_sequence?(tail, << head :: utf8 >>, quoted, separator)
  end
  defp ends_sequence?("", _, quoted, _) do
    { !quoted, "" }
  end

  defp starts_sequence?(line, separator) do
    starts_sequence?(line, "", false, separator, "")
  end
  defp starts_sequence?(<< @double_quote :: utf8 >> <> tail, last_token, false, separator, _) when last_token == << separator :: utf8 >> do
    starts_sequence?(tail, @double_quote, true, separator, tail)
  end
  defp starts_sequence?(<< @double_quote :: utf8 >> <> tail, "", false, separator, _) do
    starts_sequence?(tail, @double_quote, true, separator, tail)
  end
  defp starts_sequence?(<< @double_quote :: utf8 >> <> tail, _, quoted, separator, sequence_start) do
    starts_sequence?(tail, @double_quote, !quoted, separator, sequence_start)
  end
  defp starts_sequence?(<< head :: utf8 >> <> tail, _, quoted, separator, sequence_start) do
    starts_sequence?(tail, << head :: utf8 >>, quoted, separator, sequence_start)
  end
  defp starts_sequence?(<< head >> <> tail, _, quoted, separator, sequence_start) do
    starts_sequence?(tail, << head >>, quoted, separator, sequence_start)
  end
  defp starts_sequence?("", _, quoted, _, sequence_start) do
    { quoted, sequence_start }
  end

end
