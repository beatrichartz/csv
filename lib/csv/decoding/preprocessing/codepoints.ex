defmodule CSV.Decoding.Preprocessing.Codepoints do
  use CSV.Defaults

  alias CSV.EscapeSequenceError

  @moduledoc ~S"""
  The CSV codepoints preprocessor module - collects lines out of a stream of codepoints.
  """

  @doc """
  Collects lines respsecting common escape sequences of a stream.

  ## Options

  Options get transferred from the decoder. They are:

    * `:escape_max_lines` – The maximum number of lines to collect in an escaped field
  """

  @stream_end ""

  def process(stream, options \\ []) do
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream
        |> Stream.concat([@stream_end])
        |> Stream.transform(fn -> { "", nil, "", false, 0 } end, fn codepoint, line ->
      collect_codepoint(line, escape_max_lines, codepoint)
    end, fn { _, _, escaped_part, escaped, num_lines } ->
      if escaped do
        raise EscapeSequenceError,
                   line: num_lines + 1,
                   escape_sequence: escaped_part,
                   escape_max_lines: escape_max_lines,
                   num_escaped_lines: num_lines
      end
    end)
  end

  defp collect_codepoint({ _, _, escaped_part, true, num_lines }, escape_max_lines, << @newline :: utf8 >>) when escape_max_lines == num_lines do
    raise EscapeSequenceError,
                 line: num_lines + 1,
                 escape_sequence: escaped_part,
                 escape_max_lines: escape_max_lines,
                 num_escaped_lines: num_lines
  end
  defp collect_codepoint({ line, _, escaped_part, true, num_lines }, _, << @newline :: utf8 >>) do
    { [], { line <> << @newline :: utf8 >>, << @newline :: utf8 >>, escaped_part <> << @newline :: utf8 >>, true, num_lines + 1 } }
  end
  defp collect_codepoint({ "", _, _, false, num_lines }, _, @stream_end) do
    { [], { "", @stream_end, "", false, num_lines } }
  end
  defp collect_codepoint({ line, _, _, false, num_lines }, _, @stream_end) do
    { [line], { "", @stream_end, "", false, num_lines } }
  end
  defp collect_codepoint({ line, _, _, false, num_lines }, _, << @carriage_return :: utf8 >>) do
    { [line], { "", << @carriage_return :: utf8 >>, "", false, num_lines } }
  end
  defp collect_codepoint({ _, << @carriage_return :: utf8 >>, _, false, num_lines }, _, << @newline :: utf8 >>) do
    { [], { "", << @newline :: utf8 >>, "", false, num_lines } }
  end
  defp collect_codepoint({ line, _, _, false, num_lines }, _, << @newline :: utf8 >>) do
    { [line], { "", << @newline :: utf8 >>, "", false, num_lines } }
  end
  defp collect_codepoint({ line, _, escaped_part, true, num_lines }, _, << @double_quote :: utf8 >>) do
    { [], { line <> << @double_quote :: utf8 >>, << @double_quote :: utf8 >>, escaped_part <> << @newline :: utf8 >>, false, num_lines } }
  end
  defp collect_codepoint({ line, _, _, false, num_lines }, _, << @double_quote :: utf8 >>) do
    { [], { line <> << @double_quote :: utf8 >>, << @double_quote :: utf8 >>, "", true, num_lines } }
  end
  defp collect_codepoint({ line, _, escaped_part, true, num_lines }, _, codepoint) do
    { [], { line <> codepoint, codepoint, escaped_part <> codepoint, true, num_lines } }
  end
  defp collect_codepoint({ line, _, _, false, num_lines }, _, codepoint) do
    { [], { line <> codepoint, codepoint, "", false, num_lines } }
  end
end
