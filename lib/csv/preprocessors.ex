defmodule CSV.Preprocessors do
  alias CSV.Preprocessors.Codepoints
  alias CSV.Preprocessors.Lines

  def codepoints(stream) do
    Codepoints.process(stream)
  end

  def lines(stream, options \\ []) do
    Lines.process(stream, options)
  end
end
