defmodule CSV.Decoder do

  @moduledoc ~S"""
  The Decoder CSV module sends lines of delimited values from a stream to the parser and converts
  rows coming from the CSV parser module to a consumable stream.
  In setup, it parallelises lexing and parsing, as well as different lexer/parser pairs as pipes.
  The number of pipes can be controlled via options and influences the order of the stream.
  """
  alias CSV.Parser, as: Parser
  alias CSV.Lexer, as: Lexer

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
    headers = options |> Keyword.get(:headers, false)
    num_pipes = options |> Keyword.get(:num_pipes, @num_pipes)

    row_receiver = self
    { :ok, relay } = Task.start_link fn -> 
      row_receiver |> relay_listen
    end

    build_producer!(stream, relay, num_pipes, options) |> 
    build_consumer!(relay, num_pipes, headers)
  end

  defp relay_listen(row_receiver) do
    receive do
      :next ->
        receive do
          row ->
            send row_receiver, row
            row_receiver |> relay_listen
        end
      :halt ->
        # do nothing
    end
  end

  defp build_consumer!(producer, relay, num_pipes, headers) when is_boolean(headers) and headers do
    headers_list = build_header_consumer!(producer, relay, num_pipes) |>
                   Enum.take(1) |> List.first
    next_producer = producer |> Enum.drop(1)

    build_consumer!(next_producer, relay, num_pipes, headers_list)
  end

  defp build_consumer!(producer, relay, num_pipes, headers) do
    Stream.resource fn ->
      { producer, relay, 0, num_pipes, headers }
    end, &consume/1,
    fn _ ->
    end
  end

  defp consume({ producer, relay, index, num_pipes, headers }) do
    next_producer = producer |> Enum.drop(1)
    send relay, :next

    receive do
      { :row, { i, row } } ->
        { [build_row(row, headers)], { next_producer, relay, index + 1, num_pipes, headers } }
      { :syntax_error, { index, message } } ->
        raise Parser.SyntaxError, line: index, message: message
      { :lexer_error, { index, message } } ->
        raise Lexer.EncodingError, line: index, message: message
      { :stream_error, { value, message } } ->
        raise CSV.Decoder.StreamError, value: value, message: message
      { :halt, _ } when num_pipes > 1 ->
        { [], { producer, relay, index, num_pipes - 1, headers } }
      { :halt, _ } ->
        send relay, :halt
        { :halt, { next_producer, relay, index, 0, headers } }
    end
  end

  defp build_header_consumer!(producer, relay, num_pipes) do
    Stream.resource fn ->
      { producer, relay, 0, num_pipes }
    end, &consume_header/1,
    fn _ ->
    end
  end

  defp consume_header({ producer, relay, index, num_pipes }) do
    next_producer = producer |> Enum.drop(1)
    send relay, :next

    receive do
      { :row, { 0, row } } ->
        { [build_row(row, nil)], { next_producer, relay, index + 1, num_pipes } }
      { :row, { i, row } } ->
        consume_header({ producer, relay, index, num_pipes })
      { :syntax_error, { index, message } } ->
        raise Parser.SyntaxError, line: index, message: message
      { :lexer_error, { index, message } } ->
        raise Lexer.EncodingError, line: index, message: message
      { :stream_error, { value, message } } ->
        raise CSV.Decoder.StreamError, value: value, message: message
      { :halt, _ } when num_pipes > 1 ->
        { [], { producer, relay, index, num_pipes - 1 } }
      { :halt, _ } ->
        send relay, :halt
        { :halt, { next_producer, relay, index, 0 } }
    end
  end

  defp build_producer!(stream, relay, num_pipes, options) do
    Stream.resource fn ->
      { stream, 0, build_pipes!(relay, num_pipes, options) }
    end, &produce(&1, num_pipes), fn { reason, index, pipes } ->
      case reason do
        { :error, message } ->
          pipes |> Enum.each(&send(&1, {:stream_error, message }))
        _ ->
          pipes |> Enum.each(&send(&1, {:halt, index}))
      end
    end
  end

  defp produce({ stream, index, pipes }, num_pipes) do
    try do
      stream |> Enum.take(1) |> produce_element({ stream, index, pipes }, num_pipes)
    rescue e ->
      { :halt, { { :error, { e.value, "Stream #{e.value} can not be decoded" } }, index + 1, pipes } }
    end
  end

  defp produce_element(elements, { stream, index, pipes }, num_pipes) do
    element = elements |> List.first
    pipe_index = index |> rem(num_pipes)
    pipes |> Enum.fetch!(pipe_index) |> send({ index, element })

    if stream |> Enum.drop(1) |> Enum.empty? do
      { :halt, { stream |> Enum.drop(1), index + 1, pipes } }
    else
      { [element], { stream |> Enum.drop(1), index + 1, pipes } }
    end
  end

  defp build_pipes!(receiver, num_pipes, options) do
    1..num_pipes |> Enum.map fn _ ->
      receiver |> build_pipe!(options)
    end
  end

  defp build_pipe!(receiver, options) do
    { :ok, line_receiver } = Task.start_link fn ->
      { :ok, token_receiver } = Task.start_link fn ->
        Parser.parse_into(receiver, options)
      end

      Lexer.lex_into(token_receiver, options)
    end

    line_receiver
  end

  defp build_row(data, headers) when is_list(headers) do
    headers |> Enum.zip(data) |> Enum.into(%{})
  end

  defp build_row(data, _) do
    data
  end

end
