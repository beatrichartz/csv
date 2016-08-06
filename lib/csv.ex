defmodule CSV do

  @moduledoc ~S"""
  RFC 4180 compliant CSV parsing and encoding for Elixir. Allows to specify other separators,
  so it could also be named: TSV, but it isn't.
  """

  @doc """
  Decode a stream of comma-separated lines into a table.
  
  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint (syntax: ? + (your separator)).
    * `:delimiter`   – The delimiter token to use, defaults to `\\r\\n`. Must be a string.
    * `:strip_cells` – When set to true, will strip whitespace from cells. Defaults to false.
    * `:multiline_escape` – Whether to allow multiline escape sequences. Defaults to true.
    * `:multiline_escape_max_lines` – How many lines to maximally aggregate for multiline escapes. Defaults to a 1000.
    * `:num_pipes`   – Will be deprecated in 2.0 - see num_workers
    * `:num_workers` – The number of parallel operations to run when producing the stream.
    * `:worker_work_ratio` – The available work per worker, defaults to 5. Higher rates will mean more work sharing, but might also lead to work fragmentation slowing down the queues.
    * `:headers`     – When set to `true`, will take the first row of the csv and use it as
      header values.
      Defaults to number of erlang schedulers times 3 
      header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.

  ## Examples

  Convert a filestream into a stream of rows:

      iex> \"../test/fixtures/docs.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode
      iex> |> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Convert a filestream into a stream of rows in order of the given stream:

      iex> \"../test/fixtures/docs.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode(num_pipes: 1)
      iex> |> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Map an existing stream of lines separated by a token to a stream of rows with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.Decoder.decode(separator: ?;, headers: true)
      iex> |> Enum.take(2)
      [%{\"a\" => \"c\", \"b\" => \"d\"}, %{\"a\" => \"e\", \"b\" => \"f\"}]

  Map an existing stream of lines separated by a token to a stream of rows with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.Decoder.decode(separator: ?;, headers: [:x, :y])
      iex> |> Enum.take(2)
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

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint (syntax: ? + (your separator)).
    * `:delimiter`   – The delimiter token to use, defaults to `\\r\\n`. Must be a string.

  ## Examples

  Convert a stream of rows with cells into a stream of lines:

      iex> [~w(a b), ~w(c d)]
      iex> |> CSV.encode
      iex> |> Enum.take(2)
      [\"a,b\\r\\n\", \"c,d\\r\\n\"]

  Convert a stream of rows with cells with escape sequences into a stream of lines:

      iex> [[\"a\\nb\", \"\\tc\"], [\"de\", \"\\tf\\\"\"]]
      iex> |> CSV.encode(separator: ?\\t, delimiter: \"\\n\")
      iex> |> Enum.take(2)
      [\"\\\"a\\\\nb\\\"\\t\\\"\\\\tc\\\"\\n\", \"de\\t\\\"\\\\tf\\\"\\\"\\\"\\n\"]
  """

  def encode(stream, options \\ []) do
    CSV.Encoder.encode(stream, options)
  end

end
