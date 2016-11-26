defmodule CSV.Decoding.Preprocessing.Lines do
  use CSV.Defaults

  alias CSV.Decoding.Preprocessing.Codepoints

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
    stream
    |> Stream.transform(0, fn line, num ->
      { line |> codepoints, num + 1 }
    end)
    |> Codepoints.process(options)
  end

  defp next_codepoint(<< @newline::utf8, ""::binary >>) do
    {<< @newline::utf8 >>, ""}
  end

  defp next_codepoint(<<cp::utf8, ""::binary>>) do
    {<<cp::utf8>>, << @newline::utf8 >>}
  end

  defp next_codepoint(<<cp::utf8, rest::binary>>) do
    {<<cp::utf8>>, rest}
  end

  defp next_codepoint(<<>>) do
    nil
  end

  defp codepoints("") do
    [<< @newline :: utf8 >>]
  end

  defp codepoints(binary) when is_binary(binary) do
    do_codepoints(next_codepoint(binary))
  end

  defp do_codepoints({c, rest}) do
    [c | do_codepoints(next_codepoint(rest))]
  end

  defp do_codepoints(nil) do
    []
  end
end
