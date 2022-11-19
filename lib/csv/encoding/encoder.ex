defmodule CSV.Encoding.Encoder do
  use CSV.Defaults
  alias CSV.Encode

  @moduledoc ~S"""
  The Encoder CSV module takes a table stream and transforms it into RFC 4180
  compliant stream of lines for writing to a CSV File or other IO.
  """

  @doc """
  Encode a table stream into a stream of RFC 4180 compliant CSV lines for
  writing to a file or other IO.

  ## Options

  These are the options:

    * `:separator`        – The separator character to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + your separator).
    * `:escape_character` – The escape character to use, defaults to `?"`.
      Must be a codepoint (syntax: ? + your escape character).
    * `:delimiter`        – The delimiter token to use, defaults to `\"\\r\\n\"`.
    * `:headers`
        * When set to `false` (default), will use the raw inputs as elements.  When set to anything but `false`, all elements in the input stream are assumed to be maps.
        * When set to `true`, uses the keys of the first map as the first
    element in the stream. All subsequent elements are the values of the maps.
        * When set to a list, will use the given list as the first element
        in the stream and order all subsequent elements using that list.
        * When set to a keyword list, will use the keys of the
        keyword list to match the keys of the data, and the values of the
        keyword list to be the values in the first row of the output.
    * `:escape_formulas`   – Escape formulas to prevent
      [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

  ## Examples

  Convert a stream of rows with cells into a stream of lines:

      iex> [~w(a b), ~w(c d)]
      iex> |> CSV.Encoding.Encoder.encode
      iex> |> Enum.take(2)
      [\"a,b\\r\\n\", \"c,d\\r\\n\"]

  Convert a stream of maps into a stream of lines:

      iex> [%{"a" => 1, "b" => 2}, %{"a" => 3, "b" => 4}]
      iex> |> CSV.Encoding.Encoder.encode(headers: true)
      iex> |> Enum.to_list()
      [\"a,b\\r\\n\", \"1,2\\r\\n\", \"3,4\\r\\n\"]

  Convert a stream of rows with cells with escape sequences into a stream of
  lines:

      iex> [[\"a\\nb\", \"\\tc\"], [\"de\", \"\\tf\\\"\"]]
      iex> |> CSV.Encoding.Encoder.encode(separator: ?\\t, delimiter: \"\\n\")
      iex> |> Enum.take(2)
      [\"\\\"a\\nb\\\"\\t\\\"\\tc\\\"\\n\", \"de\\t\\\"\\tf\\\"\\\"\\\"\\n\"]
  """

  @spec encode(Enumerable.t(), [CSV.encode_options()]) :: Enumerable.t()
  def encode(stream, options \\ []) do
    headers = options |> Keyword.get(:headers, false)

    encode_stream(stream, headers, options)
  end

  defp encode_stream(stream, false, options) do
    stream
    |> Stream.transform(0, fn row, acc ->
      {[encode_row(row, options)], acc + 1}
    end)
  end

  defp encode_stream(stream, headers, options) do
    stream
    |> Stream.transform(0, fn
      row, 0 ->
        {[
           encode_row(get_headers(row, headers), options),
           encode_row(get_values(row, headers), options)
         ], 1}

      row, acc ->
        {[encode_row(get_values(row, headers), options)], acc + 1}
    end)
  end

  defp get_headers(row, true), do: Map.keys(row)

  defp get_headers(_row, headers) do
    if Keyword.keyword?(headers) do
      Keyword.values(headers)
    else
      headers
    end
  end

  defp get_values(row, true), do: Map.values(row)

  defp get_values(row, headers) do
    if Keyword.keyword?(headers) do
      headers |> Enum.map(fn {k, _} -> Map.get(row, k) end)
    else
      headers |> Enum.map(&Map.get(row, &1))
    end
  end

  defp encode_row(row, options) do
    separator = options |> Keyword.get(:separator, @separator)

    delimiter =
      options |> Keyword.get(:delimiter, <<@carriage_return::utf8>> <> <<@newline::utf8>>)

    encoded = Enum.map_join(row, <<separator::utf8>>, &encode_cell(&1, options))

    encoded <> delimiter
  end

  defp encode_cell(cell, options) do
    Encode.encode(cell, options)
  end
end
