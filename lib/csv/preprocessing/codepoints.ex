defmodule CSV.Preprocessing.Codepoints do
  use CSV.Defaults

  alias CSV.CorruptStreamError

  @moduledoc ~S"""
  The CSV codepoints preprocessor module - collects lines out of a stream of codepoints.
  """

  @doc """
  Collects lines respsecting common escape sequences of a stream.

  ## Options

  Options get transferred from the decoder. They are:

    * `:escape_max_lines` – The maximum number of lines to collect in an escaped field
  """
  def process(stream, options \\ []) do
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream |> Stream.transform(fn -> { "", false, 0 } end, fn codepoint, line ->
      collect_codepoint(line, escape_max_lines, codepoint)
    end, fn { _, escaped, _ } ->
      if escaped do
        raise CorruptStreamError,
                   message: "Stream halted with unterminated escape sequence"
      end
    end)
  end

  defp collect_codepoint({ _, true, num_lines }, escape_max_lines, << @newline :: utf8 >>) when escape_max_lines == num_lines do
    raise CorruptStreamError,
                message: "Stream halted with escape sequence spanning more than #{escape_max_lines} lines. Use the escape_max_lines option to increase this threshold."
  end
  defp collect_codepoint({ line, true, num_lines }, _, << @newline :: utf8 >>) do
    { [], { line <> << @newline :: utf8 >>, true, num_lines + 1 } }
  end
  defp collect_codepoint({ line, false, num_lines }, _, << @newline :: utf8 >>) do
    { [line], { "", false, num_lines } }
  end
  defp collect_codepoint({ line, escaped, num_lines }, _, << @double_quote :: utf8 >>) do
    { [], { line <> << @double_quote :: utf8 >>, !escaped, num_lines } }
  end
  defp collect_codepoint({ line, escaped, num_lines }, _, codepoint) do
    { [], { line <> codepoint, escaped, num_lines } }
  end
end
