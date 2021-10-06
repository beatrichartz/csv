defmodule CSV.Decoding.Decoder do
  @moduledoc ~S"""
  The Decoder CSV module sends lines of delimited values from a stream to the
  parser and converts rows coming from the CSV parser module to a consumable
  stream. In setup, it parallelises lexing and parsing, as well as different
  lexer/parser pairs as workers. The number of workers can be controlled via
  options.
  """
  alias CSV.Decoding.Parser
  alias CSV.Decoding.Lexer
  alias CSV.Defaults
  alias CSV.RowLengthError

  @doc """
  Decode a stream of comma-separated lines into a stream of rows.
  You can control the number of parallel work streams via the option
  `:num_workers` - default is the number of erlang schedulers times 3.
  The Decoder expects line by line input of valid csv lines with inlined
  escape sequences if you use it directly.

  ## Options

  These are the options:

  * `:separator`    – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
  * `:strip_fields` – When set to true, will strip whitespace from fields.
      Defaults to false.
  * `:num_workers`  – The number of parallel operations to run when producing
      the stream.
  * `:worker_work_ratio` – The available work per worker, defaults to 5.
      Higher rates will mean more work sharing, but might also lead to work
      fragmentation slowing down the queues.
  * `:headers`      – When set to `true`, will take the first row of the csv
      and use it as header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.
  * `:replacement`    – The replacement string to use where lines have bad
      encoding. Defaults to `nil`, which disables replacement.
  * `:escape_formulas – Remove Formular Escaping inserted to prevent
      [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

  ## Examples

  Convert a stream of lines with inlined escape sequences into a stream of rows:

      iex> [\"a,b\",\"c,d\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  Map an existing stream of lines separated by a token to a stream of rows with
  a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(separator: ?;, headers: true)
      ...> |> Enum.take(2)
      [
        ok: %{\"a\" => \"c\", \"b\" => \"d\"},
        ok: %{\"a\" => \"e\", \"b\" => \"f\"}
      ]

  Map an existing stream of lines separated by a token to a stream of rows with
  a header row with duplications:

      iex> [\"a;b;b\",\"c;d;e\", \"f;g;h\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(separator: ?;, headers: true)
      ...> |> Enum.take(2)
      [
        ok: %{\"a\" => \"c\", \"b\" => [\"d\", \"e\"]},
        ok: %{\"a\" => \"f\", \"b\" => [\"g\", \"h\"]}
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(separator: ?;, headers: [:x, :y])
      ...> |> Enum.take(2)
      [
        ok: %{:x => \"a\", :y => \"b\"},
        ok: %{:x => \"c\", :y => \"d\"}
      ]

  Decode a CSV string:

      iex> csv_string = \"id,name\\r\\n1,Jane\\r\\n2,George\\r\\n3,John\"
      ...> {:ok, out} = csv_string |> StringIO.open
      ...> out
      ...> |> IO.binstream(:line)
      ...> |> CSV.Decoding.Decoder.decode(headers: true)
      ...> |> Enum.map(&(&1))
      [
        ok: %{\"id\" => \"1\", \"name\" => \"Jane\"},
        ok: %{\"id\" => \"2\", \"name\" => \"George\"},
        ok: %{\"id\" => \"3\", \"name\" => \"John\"}
      ]

  """

  def decode(stream, options \\ []) do
    options = options |> with_defaults

    stream
    |> Stream.with_index()
    |> with_headers(options)
    |> with_row_length(options)
    |> decode_rows(options)
  end

  defp with_defaults(options) do
    options
    |> Keyword.merge(
      num_workers: options |> Keyword.get(:num_workers, Defaults.num_workers()),
      headers: options |> Keyword.get(:headers, false)
    )
  end

  defp decode_rows(stream, options) do
    stream
    |> ParallelStream.map(&decode_row(&1, options), options)
  end

  defp decode_row({nil, 0}, _) do
    {:ok, []}
  end

  defp decode_row({line, index, headers, row_length}, options) do
    with {:ok, parsed, _} <- parse_row({line, index}, options),
         {:ok, _} <- validate_row_length({parsed, index}, row_length),
         do: build_row(parsed, headers)
  end

  defp parse_row({line, index}, options) do
    with {:ok, lex, _} <- Lexer.lex({line, index}, options),
         do: Parser.parse({lex, index}, options)
  end

  defp build_row(data, headers) when is_list(headers) do
    zipped_data =
      headers
      |> Enum.zip(data)
      |> Enum.reduce(%{}, fn {key, value}, row ->
        case Map.get(row, key, :default_value) do
          :default_value ->
            Map.put(row, key, value)

          multiple_values when is_list(multiple_values) ->
            Map.put(row, key, multiple_values ++ [value])

          existing_value ->
            Map.put(row, key, [existing_value, value])
        end
      end)

    {:ok, zipped_data}
  end

  defp build_row(data, _), do: {:ok, data}

  defp with_headers(stream, options) do
    headers = options |> Keyword.get(:headers, false)
    stream |> Stream.transform({headers, options}, &add_headers/2)
  end

  defp add_headers({line, 0}, {headers, options}) when is_list(headers) do
    {[{line, 0, headers}], {headers, options}}
  end

  defp add_headers({line, 0}, {true, options}) do
    case parse_row({line, 0}, options) do
      {:ok, headers, _} ->
        {[], {headers, options}}

      _ ->
        {[], {false, options}}
    end
  end

  defp add_headers({line, 0}, {false, options}) do
    {[{line, 0, false}], {false, options}}
  end

  defp add_headers({line, index}, {headers, options}) do
    {[{line, index, headers}], {headers, options}}
  end

  defp with_row_length(stream, options) do
    validate_row_length_option = options |> Keyword.get(:validate_row_length, true)

    stream |> Stream.transform({validate_row_length_option, options}, &add_row_length/2)
  end

  defp add_row_length({line, index, headers}, {false, options}) do
    {[{line, index, headers, false}], {false, options}}
  end

  defp add_row_length({line, 0, false}, {true, options}) do
    case parse_row({line, 0}, options) do
      {:ok, row, _} ->
        row_length = row |> Enum.count()
        {[{line, 0, false, row_length}], {row_length, options}}

      _ ->
        {[{line, 0, false, false}], {false, options}}
    end
  end

  defp add_row_length({line, index, headers}, {true, options}) when is_list(headers) do
    row_length = headers |> Enum.count()
    {[{line, index, headers, row_length}], {row_length, options}}
  end

  defp add_row_length({line, index, headers}, {row_length, options}) do
    {[{line, index, headers, row_length}], {row_length, options}}
  end

  defp validate_row_length({data, _}, false), do: {:ok, data}
  defp validate_row_length({data, _}, nil), do: {:ok, data}

  defp validate_row_length({data, index}, expected_length) do
    case data |> Enum.count() do
      ^expected_length ->
        {:ok, data}

      actual_length ->
        {:error, RowLengthError,
         "Row has length #{actual_length} - expected length #{expected_length}", index}
    end
  end
end
