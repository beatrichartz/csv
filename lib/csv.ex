defmodule CSV do

  @doc """
  Decode a stream of comma-separated lines into a table.
  If the number of parallel operations (set via the option `:num_pipes` and defaulting to 8)
  is greater than 1, this will produce the rows of the file out of order. If parallel operations
  are set to one, lexing and parsing are still parallelised, which results in better performance.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `\",\"`. Can only be a single token.
    * `:strip_cells` – When set to true, will strip whitespace from cells. Defaults to false.
    * `:num_pipes`   – The number of parallel operations to run when producing the stream.
      If set to 1, the stream will produce the CSV lines in order at the
      cost of performance. Defaults to `8`.
    * `:headers`     – When set to `true`, will take the first row of the csv and use it as
      header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.

  ## Examples

  Convert a filestream into a stream of rows:

      iex> File.stream!(\"data.csv\") |>
      iex> CSV.decode |>
      iex> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Convert a filestream into a stream of rows in order of the given stream:

      iex> File.stream!(\"data.csv\") |>
      iex> CSV.decode(num_pipes: 1) |>
      iex> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Map an existing stream of lines separated by a token to a stream of rows with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"] |>
      iex> Stream.map(&(&1)) |>
      iex> CSV.decode(separator: \";\", headers: true) |>
      iex> Enum.take(2)
      [%{\"a\" => \"c\", \"b\" => \"d\"}, %{\"a\" => \"e\", \"b\" => \"f\"}]

  Map an existing stream of lines separated by a token to a stream of rows with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"] |>
      iex> Stream.map(&(&1)) |>
      iex> CSV.decode(separator: \";\", headers: [:x, :y]) |>
      iex> Enum.take(2)
      [%{:x => \"a\", :y => \"b\"}, %{:x => \"c\", :y => \"d\"}]
  """

  def decode(stream, options \\ []) do
    CSV.Decoder.decode(stream, options)
  end


  @doc """
  Encode a table stream into a stream of RFC 4180 compliant CSV lines for writing to a file
  or other IO.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `\",\"`. Can only be a single token.
    * `:delimiter`   – The delimiter token to use, defaults to `\"\\r\\n\"`.

  ## Examples

  Convert a stream of rows with cells into a stream of lines:

      iex> [~w(a b), ~w(c d)] |>
      iex> CSV.encode |>
      iex> Enum.take(2)
      [\"a,b\\r\\n\", \"c,d\\r\\n\"]

  Convert a stream of rows with cells with escape sequences into a stream of lines:

      iex> [[\"a\\nb\", \"\\tc\"], [\"de\", \"\\tf\\\"\"]] |>
      iex> CSV.encode(separator: \"\\t\", delimiter: \"\\n\") |>
      iex> Enum.take(2)
      [\"\\\"a\\nb\\\"\\t\\\"\\tc\\\"\\n\", \"de\\t\\\"\\tf\\\"\\\"\\\"\\n\"]
  """

  def encode(stream, options \\ []) do
    CSV.Encoder.encode(stream, options)
  end

end
