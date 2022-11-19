defmodule CSV.Decoding.Decoder do
  use CSV.Defaults

  @moduledoc ~S"""
  The Decoder CSV module sends lines of delimited values from a stream to the
  parser and converts rows coming from the CSV parser module to a consumable
  stream.
  """
  alias CSV.Decoding.Parser
  alias CSV.RowLengthError

  @doc """
  Decode a stream of comma-separated lines into a stream of rows that are
  either lists of fields or maps of headers to fields.
  The Decoder expects line or variable size byte stream input.

  ## Options

  These are the options:

  * `:separator`           – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
  * `:escape_character`    – The escape character token to use, defaults to `?"`.
      Must be a codepoint (syntax: ? + (your escape character)).
  * `:escape_max_lines`    – The number of lines an escape sequence is allowed 
      to span, defaults to 10.
  * `:field_transform`     – A function with arity 1 that will get called with
      each field and can apply transformations. Defaults to identity function.
      This function will get called for every field and therefore should return
      quickly.
  * `:headers`             – When set to `true`, will take the first row of
      the csv and use it as header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.
  * `:validate_row_length` – When set to `true`, will take the first row of
      the csv or its headers and validate that following rows are of the same
      length. Defaults to `false`.
  * `:escape_formulas`      – When set to `true`, will remove formula escaping
      inserted to prevent [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

  ## Examples

  Convert a stream with inlined escape sequences into a stream of rows:

      iex> [\"a,b\\n\",\"c,d\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  Convert a stream with custom escape characters into a stream of rows:

      iex> [\"@a@,@b@\\n\",\"@c@,@d@\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(escape_character: ?@)
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  Convert a line stream with escape sequences into a stream of rows:

      iex> [\"'@a,'=b\\n\",\"'-c,'+d\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(unescape_formulas: true)
      ...> |> Enum.take(2)
      [ok: [\"@a\", \"=b\"], ok: [\"-c\", \"+d\"]]

  Trim each field:

      iex> [\" a , b   \\n\",\" c   ,   d \\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(field_transform: &String.trim/1)
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  Read from a file with a Byte Order Mark (BOM):

      iex> \"../../../test/fixtures/utf8-with-bom.csv\"
      ...> |> Path.expand(__DIR__)
      ...> |> File.stream!([:trim_bom])
      ...> |> CSV.Decoding.Decoder.decode()
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"d\", \"e\"]]

  Replace invalid codepoints:

      iex> \"../../../test/fixtures/broken-encoding.csv\"
      ...> |> Path.expand(__DIR__)
      ...> |> File.stream!()
      ...> |> CSV.Decoding.Decoder.decode(field_transform: fn field ->
      ...>   if String.valid?(field) do
      ...>     field
      ...>   else
      ...>     field
      ...>     |> String.codepoints()
      ...>     |> Enum.map(fn codepoint -> if String.valid?(codepoint), do: codepoint, else: "?" end)
      ...>     |> Enum.join()
      ...>   end
      ...> end)
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\", \"c\", \"?_?\"], ok: [\"ಠ_ಠ\"]]

  Map an existing stream of lines separated by a token to a stream of rows with
  a header row:

      iex> [\"a;b\\n\",\"c;d\\n\", \"e;f\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(separator: ?;, headers: true)
      ...> |> Enum.take(2)
      [
        ok: %{\"a\" => \"c\", \"b\" => \"d\"},
        ok: %{\"a\" => \"e\", \"b\" => \"f\"}
      ]

  Map an existing stream of lines separated by a token to a stream of rows with
  a header row with duplications:

      iex> [\"a;b;b\\n\",\"c;d;e\\n\", \"f;g;h\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(separator: ?;, headers: true)
      ...> |> Enum.take(2)
      [
        ok: %{\"a\" => \"c\", \"b\" => [\"d\", \"e\"]},
        ok: %{\"a\" => \"f\", \"b\" => [\"g\", \"h\"]}
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a given header row:

      iex> [\"a;b\\n\",\"c;d\\n\", \"e;f\\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.Decoding.Decoder.decode(separator: ?;, headers: [:x, :y])
      ...> |> Enum.take(2)
      [
        ok: %{:x => \"a\", :y => \"b\"},
        ok: %{:x => \"c\", :y => \"d\"}
      ]

  Decode a CSV string:

      iex> [\"id,name\\r\\n1,Jane\\r\\n2,George\\r\\n3,John\"]
      ...> |> CSV.Decoding.Decoder.decode(headers: true)
      ...> |> Enum.map(&(&1))
      [
        ok: %{\"id\" => \"1\", \"name\" => \"Jane\"},
        ok: %{\"id\" => \"2\", \"name\" => \"George\"},
        ok: %{\"id\" => \"3\", \"name\" => \"John\"}
      ]

  """
  @type decode_options :: CSV.decode_options()

  @spec decode(Enumerable.t(), [decode_options()]) :: Enumerable.t()
  def decode(stream, options \\ []) do
    options = options |> with_defaults

    stream
    |> Parser.parse(options)
    |> validate_row_length(options)
    |> with_headers(options)
  end

  defp with_defaults(options) do
    options
    |> Keyword.merge(headers: options |> Keyword.get(:headers, false))
  end

  defp build_row_with_headers(data, headers) do
    row_with_headers =
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

    {:ok, row_with_headers}
  end

  defp with_headers(stream, options) do
    headers = options |> Keyword.get(:headers, false)

    case headers do
      false ->
        stream

      _ ->
        stream
        |> Stream.transform(
          fn -> headers end,
          &add_headers/2,
          fn _ -> :ok end
        )
    end
  end

  defp add_headers({:ok, data}, headers) when is_list(headers) do
    {[build_row_with_headers(data, headers)], headers}
  end

  defp add_headers({:ok, data}, true) do
    {[], data}
  end

  defp add_headers({:error, _, _} = result, headers) do
    {[result], headers}
  end

  defp validate_row_length(stream, options) do
    validate_row_length = options |> Keyword.get(:validate_row_length, false)
    headers = options |> Keyword.get(:headers)

    case validate_row_length do
      true when is_list(headers) ->
        stream
        |> Stream.with_index()
        |> Stream.transform(Enum.count(headers), &add_row_length_errors/2)

      true ->
        stream |> Stream.with_index() |> Stream.transform(:undefined, &add_row_length_errors/2)

      _ ->
        stream
    end
  end

  defp add_row_length_errors({{:ok, row} = result, _}, :undefined) do
    {[result], Enum.count(row)}
  end

  defp add_row_length_errors({{:error, _, _} = result, _}, state) do
    {[result], state}
  end

  defp add_row_length_errors({{:ok, row} = result, index}, expected_length) do
    case Enum.count(row) do
      ^expected_length ->
        {[result], expected_length}

      actual_length ->
        {[
           {:error, RowLengthError,
            [
              actual_length: actual_length,
              expected_length: expected_length,
              row: index + 1
            ]}
         ], expected_length}
    end
  end
end
