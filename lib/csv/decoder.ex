defmodule CSV.Decoder do

  @moduledoc ~S"""
  The Decoder CSV module sends lines of delimited values from a stream to the parser and converts
  rows coming from the CSV parser module to a consumable stream.
  In setup, it parallelises lexing and parsing, as well as different lexer/parser pairs as pipes.
  The number of pipes can be controlled via options and influences the order of the stream.
  """
  alias CSV.Parser, as: Parser
  alias CSV.Lexer, as: Lexer
  alias CSV.Relay, as: Relay

  @num_pipes 8

  @doc """
  Decode a stream of comma-separated lines into a table.
  If the number of parallel operations (set via the option `:num_pipes` and defaulting to 8)
  is greater than 1, this will produce the rows of the file out of order. If parallel operations
  are set to one, lexing and parsing are still parallelised, which results in better performance.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint (syntax: ? + (your separator)).
    * `:delimiter`   – The delimiter token to use, defaults to `\r\n`. Must be a string.
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
      iex> CSV.Decoder.decode |>
      iex> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Convert a filestream into a stream of rows in order of the given stream:

      iex> File.stream!(\"data.csv\") |>
      iex> CSV.Decoder.decode(num_pipes: 1) |>
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

  def decode(stream, options \\ []) do
    { headers, stream } = options |> Keyword.get(:headers, false) |> get_headers!(stream, options)
    num_pipes = options |> Keyword.get(:num_pipes, @num_pipes)
    pipes = num_pipes |> build_pipes!(options)

    producer = stream |> build_producer!(pipes) 
    consumer = producer |> build_consumer!(headers)

    consumer
  end

  defp get_headers!(headers, stream, options) when is_list(headers) do
    { headers, stream }
  end
  defp get_headers!(headers, stream, options) when headers do
    producer = stream |> build_producer!([self |> build_pipe!(options)]) 
    consumer = producer |> build_consumer!(false)
    { consumer |> Enum.drop(-1) |> List.first, stream |> Stream.drop(1) }
  end
  defp get_headers!(_, stream, _) do
    { false, stream }
  end

  defp build_producer!(stream, pipes) do
    num_pipes = pipes |> Enum.count

    Stream.transform stream, fn -> 0 end, fn line, index ->
      pipe_index = index |> rem(num_pipes)
      { line_receiver, relay } = pipes |> Enum.fetch!(pipe_index)
      line_receiver |> send({ index, line })

      { [{ relay, index }], index + 1 }
    end, fn index -> 
      pipes |> Enum.each fn { line_receiver, relay } ->
        relay |> send :halt
        line_receiver |> send { :halt, index }
      end
    end
  end

  defp build_consumer!(stream, headers) do
    Stream.transform stream, 0, fn { relay, index }, acc ->
      relay |> send :next
      receive do
        { ^relay, { :row, { ^index, row } } } ->
          { [build_row(row, headers)], acc + 1 }
        { ^relay, { :syntax_error, { index, message } } } ->
          raise Parser.SyntaxError, line: index, message: message
        { ^relay, { :lexer_error, { index, message } } } ->
          raise Lexer.EncodingError, line: index, message: message
      end
    end
  end

  defp build_pipes!(num_pipes, options) do
    1..num_pipes |> Enum.map fn _ ->
      self |> build_pipe!(options)
    end
  end

  defp build_pipe!(receiver, options) do
    { :ok, relay } = Task.start_link fn ->
      Relay.listen(receiver) 
    end
    { :ok, line_receiver } = Task.start_link fn ->
      { :ok, token_receiver } = Task.start_link fn ->
        Parser.parse_into(relay, options)
      end

      Lexer.lex_into(token_receiver, options)
    end

    { line_receiver, relay }
  end

  defp build_row(data, headers) when is_list(headers) do
    headers |> Enum.zip(data) |> Enum.into(%{})
  end

  defp build_row(data, _) do
    data
  end

end
