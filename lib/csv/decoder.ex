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
      ...> |> Path.expand(__DIR__)
      ...> |> File.stream!
      ...> |> CSV.Decoder.decode!
      ...> |> Enum.take(2)
      [[\"a\", \"b\", \"c\"], [\"d\", \"e\", \"f\"]]

  Map an existing stream of lines separated by a token to a stream of rows with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoder.decode!(separator: ?;, headers: true)
      ...> |> Enum.take(2)
      [%{\"a\" => \"c\", \"b\" => \"d\"}, %{\"a\" => \"e\", \"b\" => \"f\"}]

  Map an existing stream of lines separated by a token to a stream of rows with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoder.decode!(separator: ?;, headers: [:x, :y])
      ...> |> Enum.take(2)
      [%{:x => \"a\", :y => \"b\"}, %{:x => \"c\", :y => \"d\"}]

  Decode a CSV string

      iex> csv_string = \"id,name\\r\\n1,Jane\\r\\n2,George\\r\\n3,John\"
      ...> {:ok, out} = csv_string |> StringIO.open
      ...> out
      ...> |> IO.binstream(:line)
      ...> |> CSV.Decoder.decode!(headers: true)
      ...> |> Enum.map(&(&1))
      [%{\"id\" => \"1\", \"name\" => \"Jane\"}, %{\"id\" => \"2\", \"name\" => \"George\"}, %{\"id\" => \"3\", \"name\" => \"John\"}]
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
    options = options
              |> with_defaults

    stream
    |> aggregate(options)
    |> Stream.with_index
    |> with_headers(options)
    |> with_row_length(options)
    |> decode_rows(options)
  end

  defp with_defaults(options) do
    num_pipes = options |> Keyword.get(:num_pipes, Defaults.num_workers)

    options
    |> Keyword.merge(num_pipes: num_pipes,
                     num_workers: options |> Keyword.get(:num_workers, num_pipes),
                     multiline_escape: options |> Keyword.get(:multiline_escape, true),
                     headers: options |> Keyword.get(:headers, false))
  end

  defp decode_rows(stream, options) do
    stream
    |> ParallelStream.map(&(decode_row(&1, options)), options)
  end

  defp decode_row({ nil, 0 }, _) do
    { :ok, [] }
  end
  defp decode_row({ line, index, headers, row_length }, options) do
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
      true -> stream |> LineAggregator.aggregate(options)
      _ -> stream
    end
  end

  defp build_row(data, headers) when is_list(headers) do
    { :ok, headers |> Enum.zip(data) |> Enum.into(%{}) }
  end
  defp build_row(data, _), do: { :ok, data }

  defp with_headers(stream, options) do
    headers = options |> Keyword.get(:headers, false)
    stream |> Stream.transform({ headers, options }, &add_headers/2)
  end

  defp add_headers({ line, 0 }, { headers, options }) when is_list(headers) do
    { [{ line, 0, headers }], { headers, options } }
  end
  defp add_headers({ line, 0 }, { true, options }) do
    case parse_row({ line, 0 }, options) do
      { :ok, headers, _ } ->
        { [], { headers, options } }
      _ ->
        { [], { false, options } }
    end
  end
  defp add_headers({ line, 0 }, { false, options }) do
    { [{ line, 0, false }], { false, options } }
  end
  defp add_headers({ line, index }, { headers, options }) do
    { [{ line, index, headers }], { headers, options } }
  end

  defp with_row_length(stream, options) do
    stream |> Stream.transform({ nil, options }, &add_row_length/2)
  end

  defp add_row_length({ line, 0, false }, { row_length, options }) do
    case parse_row({ line, 0 }, options) do
      { :ok, row, _ } ->
        row_length = row |> Enum.count
        { [{ line, 0, false, row_length }], { row_length, options } }
      _ ->
        { [{ line, 0, false, false }], { row_length, options } }
    end
  end
  defp add_row_length({ line, _, headers }, { nil, options }) when is_list(headers) do
    row_length = headers |> Enum.count
    { [{ line, 0, headers, row_length }], { row_length, options } }
  end
  defp add_row_length({ line, index, headers }, { row_length, options }) do
    { [{ line, index, headers, row_length }], { row_length, options } }
  end

  defp validate_row_length({ data, _}, false), do: { :ok, data }
  defp validate_row_length({ data, _}, nil), do: { :ok, data }
  defp validate_row_length({ data, index }, expected_length) do
    case data |> Enum.count do
      ^expected_length -> { :ok, data }
      actual_length -> { :error, RowLengthError, "Encountered a row with length #{actual_length} instead of #{expected_length}", index }
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

end
