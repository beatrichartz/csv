defmodule CSV.Preprocessors.Codepoints do
  use CSV.Defaults

  def process(stream) do
    stream |> Stream.transform(fn -> { "", false } end, fn codepoint, line ->
      collect_codepoint(line, codepoint)
    end, &(&1))
  end

  defp collect_codepoint({ line, true }, << @newline :: utf8 >>) do
    { [], { line <> "\n", true } }
  end
  defp collect_codepoint({ line, false }, << @newline :: utf8 >>) do
    { [line], { "", false } }
  end
  defp collect_codepoint({ line, escaped }, << @double_quote :: utf8 >>) do
    { [], { line <> "\"", !escaped } }
  end
  defp collect_codepoint({ line, escaped }, codepoint) do
    { [], { line <> codepoint, escaped } }
  end
end
