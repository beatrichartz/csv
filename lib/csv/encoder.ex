defmodule CSV.Encoder do
  use CSV.Defaults

  @moduledoc ~S"""
  The Encoder CSV module takes a table stream and transforms it into RFC 4180 compliant
  stream of lines for writing to a CSV File or other IO.
  """

  @doc """
  Encode a table stream into a stream of RFC 4180 compliant CSV lines for writing to a file
  or other IO.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint (syntax: ? + your separator token).
    * `:delimiter`   – The delimiter token to use, defaults to `\"\\r\\n\"`.

  ## Examples

  Convert a stream of rows with cells into a stream of lines:

      iex> [~w(a b), ~w(c d)] |>
      iex> CSV.Encoder.encode |>
      iex> Enum.take(2)
      [\"a,b\\r\\n\", \"c,d\\r\\n\"]

  Convert a stream of rows with cells with escape sequences into a stream of lines:

      iex> [[\"a\\nb\", \"\\tc\"], [\"de\", \"\\tf\\\"\"]] |>
      iex> CSV.Encoder.encode(separator: ?\t, delimiter: \"\\n\") |>
      iex> Enum.take(2)
      [\"\\\"a\\nb\\\"\\t\\\"\\tc\\\"\\n\", \"de\\t\\\"\\tf\\\"\\\"\\\"\\n\"]
  """

  def encode(stream, options \\ []) do
    separator = options |> Keyword.get(:separator, @separator)
    delimiter = options |> Keyword.get(:delimiter, @delimiter)

    stream |> Stream.transform 0, fn row, acc ->
      {[ encode_row(row, separator, delimiter) <> delimiter ], acc + 1}
    end
  end

  defp encode_row(row, separator, delimiter) do
    row |> Enum.map(&encode_cell(&1, separator, delimiter)) |> Enum.join(<< separator :: utf8 >>)
  end

  defp encode_cell(cell, separator, delimiter) do
    CSV.Encode.encode(cell, separator: separator, delimiter: delimiter)
  end

end
