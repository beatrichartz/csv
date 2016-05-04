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

      iex> \"../../test/fixtures/docs.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.Decoder.decode!
      iex> |> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Map an existing stream of lines separated by a token to a stream of rows with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.Decoder.decode!(separator: ?;, headers: true)
      iex> |> Enum.take(2)
      [%{\"a\" => \"c\", \"b\" => \"d\"}, %{\"a\" => \"e\", \"b\" => \"f\"}]

  Map an existing stream of lines separated by a token to a stream of rows with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.Decoder.decode!(separator: ?;, headers: [:x, :y])
      iex> |> Enum.take(2)
      [%{:x => \"a\", :y => \"b\"}, %{:x => \"c\", :y => \"d\"}]
  """

  def decode!(stream, options \\ []) do
    stream
    |> decode_stream(options)
    |> raise_errors!
  end

  def decode(stream, options \\ []) do
    stream
    |> decode_stream(options)
    |> simplify_errors
  end

  defp decode_stream(stream, options) do
    stream
    |> with_default_options(options)
    |> prepare_headers
    |> prepare_row_length
    |> decode_rows
  end

  defp decode_rows({ stream, options }) do
    stream
    |> aggregate(options)
    |> Stream.with_index
    |> ParallelStream.map(&(decode_row(&1, options)), options)
  end

  defp decode_row({ nil, 0 }, _) do
    { :ok, [] }
  end
  defp decode_row({ line, index }, options) do
    headers = options |> Keyword.get(:headers)
    row_length = options |> Keyword.get(:row_length)

    with { :ok, parsed, _ } <- parse_row({ line, index }, options),
    { :ok, _ } <- validate_row_length({ parsed, index }, row_length),
    do: build_row(parsed, headers)
  end

  defp parse_row({ line, index}, options) do
    with { :ok, lex, _ } <- Lexer.lex({ line, index }, options),
    do: Parser.parse({ lex, index }, options)
  end

  defp aggregate(stream, options) do
    case options |> Keyword.get(:multiline_escape) do
      true -> stream |> LineAggregator.aggregate
      _ -> stream
    end
  end

  defp build_row(data, headers) when is_list(headers) do
    { :ok, headers |> Enum.zip(data) |> Enum.into(%{}) }
  end
  defp build_row(data, _), do: { :ok, data }

  defp with_default_options(stream, options) do
    num_pipes = options |> Keyword.get(:num_pipes, Defaults.num_workers)

    options = options
    |> Keyword.merge(num_pipes: num_pipes,
                     num_workers: options |> Keyword.get(:num_workers, num_pipes),
                     multiline_escape: options |> Keyword.get(:multiline_escape, true),
                     headers: options |> Keyword.get(:headers, false),
                     row_length: false)

    { stream, options }
  end

  defp prepare_headers({ stream, options } = payload) do
    case options |> Keyword.get(:headers) do
      true -> 
        { stream |> Stream.drop(1),
          options |> Keyword.put(:headers, get_first_row(stream, options)) }
      _ -> payload
    end
  end

  defp prepare_row_length({ stream, options }) do
    headers = options |> Keyword.get(:headers)
    first_row = if headers, do: headers, else: stream |> get_first_row(options)
    { stream,
      options |> Keyword.put(:row_length, Enum.count(first_row)) }
  end

  defp validate_row_length({ data, _}, false), do: { :ok, data }
  defp validate_row_length({ data, index }, expected_length) do
    case data |> Enum.count do
      ^expected_length -> { :ok, data }
      actual_length -> { :error, RowLengthError, "Encountered a row with length #{actual_length} instead of #{expected_length}", index }
    end
  end

  defp get_first_row(stream, options) do
    row = stream
            |> LineAggregator.aggregate(options)
            |> Enum.take(1)
            |> List.first

    case decode_row({ row, 0 }, options) do
      { :ok, data } -> data
      _ -> []
    end
  end

  defp raise_errors!(stream) do
    stream |> Stream.map(&monad_value!/1)
  end

  defp monad_value!({ :error, mod, message, index }) do
    raise mod, message: message, line: index + 1
  end
  defp monad_value!({ :ok, row }), do: row

  defp simplify_errors(stream) do
    stream |> Stream.map(&simplify_error/1)
  end

  defp simplify_error({ :error, _, message, _ }) do
    { :error, message }
  end
  defp simplify_error(monad), do: monad


  
  def decode_as_map(enum, options \\ []) do
    enum
    |> CSV.decode(options)
    |> Stream.transform(:first, &structure_from_header/2)
    |> Stream.drop(1)
  end

  #The accumulator should initially be :first, the its set to the structure of the csv
  #which is the first line
  defp structure_from_header(line, :first) do
    structure = line
      |> Enum.map(&String.to_atom/1)
    
    { [ nil ], structure }
  end

  #zips the stucture and the current line into a map
  defp structure_from_header(line, structure) do
    map = 
      structure
      |> Enum.zip(line)
      |> Enum.into(%{})

    { [ map ], structure }
  end

end
