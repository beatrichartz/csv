defmodule CSV.Decoder do

  @moduledoc ~S"""
  The Decoder CSV module sends lines of delimited values from a stream to the parser and converts
  rows coming from the CSV parser module to a consumable stream.
  In setup, it parallelises lexing and parsing, as well as different lexer/parser pairs as pipes.
  The number of pipes can be controlled via options.
  """
  alias CSV.LineAggregator
  alias CSV.Parser
  alias CSV.Lexer
  alias CSV.Defaults
  alias CSV.Decoder.RowLengthError

  @doc """
  Decode a stream of comma-separated lines into a table.
  You can control the number of parallel operations via the option `:num_pipes` - 
  default is the number of erlang schedulers times 3.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint (syntax: ? + (your separator)).
    * `:delimiter`   – The delimiter token to use, defaults to `\\r\\n`. Must be a string.
    * `:strip_cells` – When set to true, will strip whitespace from cells. Defaults to false.
    * `:multiline_escape` – Whether to allow multiline escape sequences. Defaults to true.
    * `:num_pipes`   – Will be deprecated in 2.0 - see num_workers
    * `:num_workers` – The number of parallel operations to run when producing the stream.
    * `:worker_work_ratio` – The available work per worker, defaults to 5. Higher rates will mean more work sharing, but might also lead to work fragmentation slowing down the queues.
    * `:headers`     – When set to `true`, will take the first row of the csv and use it as
      header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.

  ## Examples

  Convert a filestream into a stream of rows:

      iex> File.stream!(\"data.csv\") |>
      iex> CSV.Decoder.decode |>
      iex> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Map an existing stream of lines separated by a token to a stream of rows with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"] |>
      iex> Stream.map(&(&1)) |>
      iex> CSV.Decoder.decode(separator: ?;, headers: true) |>
      iex> Enum.take(2)
      [%{\"a\" => \"c\", \"b\" => \"d\"}, %{\"a\" => \"e\", \"b\" => \"f\"}]

  Map an existing stream of lines separated by a token to a stream of rows with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"] |>
      iex> Stream.map(&(&1)) |>
      iex> CSV.Decoder.decode(separator: ?;, headers: [:x, :y]) |>
      iex> Enum.take(2)
      [%{:x => \"a\", :y => \"b\"}, %{:x => \"c\", :y => \"d\"}]
  """

  def decode!(stream, options \\ []) do
    decode(stream, options)
    |> raise_errors!
  end

  def decode(stream, options \\ []) do
    { stream, options |> options_with_defaults }
    |> prepare_headers
    |> prepare_row_length
    |> decode_stream
  end

  defp decode_stream({ stream, %{ multiline_escape: multiline_escape } = options }) do
    stream
    |> aggregate(multiline_escape)
    |> Stream.with_index
    |> ParallelStream.map(&(decode_row(&1, options)),
                          options |> Enum.into([]))
  end

  defp decode_row({ nil, 0 }, %{ row_length: false }), do: { :ok, [] }
  defp decode_row({ line, index }, %{ headers: headers, row_length: row_length } = options) do
    with { :ok, parsed, _ } <- parse_row({ line, index }, options |> Enum.into([])),
         { :ok } <- check_row_length({ parsed, index }, row_length),
         do: build_row(parsed, headers)
  end

  defp parse_row({ line, index}, options) do
    with { :ok, lex, _ } <- Lexer.lex({ line, index }, options),
    do: Parser.parse({ lex, index }, options)
  end

  defp aggregate(stream, true) do
    stream |> LineAggregator.aggregate
  end
  defp aggregate(stream, false), do: stream

  defp build_row(data, headers) when is_list(headers) do
    { :ok, headers |> Enum.zip(data) |> Enum.into(%{}) }
  end
  defp build_row(data, _), do: { :ok, data }

  defp options_with_defaults(options) do
    num_pipes = options |> Keyword.get(:num_pipes, Defaults.num_workers)
    options
    |> Keyword.merge(num_pipes: num_pipes,
                     num_workers: options |> Keyword.get(:num_workers, num_pipes),
                     multiline_escape: options |> Keyword.get(:multiline_escape, true),
                     headers: options |> Keyword.get(:headers, false),
                     row_length: false)
    |> Enum.into(%{})
  end

  defp prepare_headers({ stream, %{ headers: true } = options }) do
    { stream |> Stream.drop(1),
      %{ options | :headers => get_first_row(stream, options) } }
  end
  defp prepare_headers(job), do: job

  defp prepare_row_length({ stream, %{ headers: headers } = options}) do
    { stream, %{ options | :row_length => get_row_length(headers || stream, options) } }
  end

  defp check_row_length(_, false), do: { :ok }
  defp check_row_length({ data, index }, row_length) do
    actual_length = get_row_length(data)

    case actual_length do
      ^row_length -> { :ok }
      _ -> { :error, RowLengthError, "Encountered a row with length #{actual_length} instead of #{row_length}", index }
    end
  end

  defp get_row_length(%Stream{} = stream, options) do
    stream
    |> get_first_row(options)
    |> get_row_length
  end
  defp get_row_length(row, _), do: row |> get_row_length
  defp get_row_length(row), do: Enum.count(row)

  defp get_first_row(stream, options) do
    row = stream
            |> LineAggregator.aggregate(options |> Enum.into([]))
            |> Enum.take(1)
            |> List.first
    { :ok, data } = decode_row({ row, 0 }, options)
    data
  end

  defp raise_errors!(stream) do
    stream |> Stream.map(&monad_value!/1)
  end
  defp monad_value!({ :error, mod, message, index }) do
    raise mod, message: message, line: index + 1
  end
  defp monad_value!({ :ok, row }), do: row

end
