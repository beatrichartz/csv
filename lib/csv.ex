defmodule CSV do
  use CSV.Defaults

  alias CSV.Decoding.Preprocessing
  alias CSV.Decoding.Decoder
  alias CSV.Encoding.Encoder
  alias CSV.EscapeSequenceError
  alias CSV.StrayQuoteError

  @moduledoc ~S"""
  RFC 4180 compliant CSV parsing and encoding for Elixir. Allows to specify
  other separators, so it could also be named: TSV, but it isn't.
  """

  @doc """
  Decode a stream of comma-separated lines into a stream of tuples. Decoding
  errors will be inlined into the stream.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
    * `:strip_fields` – When set to true, will strip whitespace from cells.
      Defaults to false.
    * `:preprocessor` – Which preprocessor to use:
        :lines (default) -> Will preprocess line by line input respecting
        escape sequences
        :none -> Will not preprocess input and expects line by line input
        with multiple line escape sequences aggregated to one line
    * `:validate_row_length` – If set to `false`, will disable validation for
      row length. This will allow for rows with variable length. Defaults to
      `true`
    * `:escape_max_lines` – How many lines to maximally aggregate for multiline
      escapes. Defaults to a 1000.
    * `:num_workers` – The number of parallel operations to run when
      producing the stream.
    * `:worker_work_ratio` – The available work per worker, defaults to 5.
      Higher rates will mean more work sharing, but might also lead to work
      fragmentation slowing down the queues.
    * `:headers`     – When set to `true`, will take the first row of the csv
      and use it as header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.

  ## Examples

  Convert a filestream into a stream of rows in order of the given stream:

      iex> \"../test/fixtures/docs/valid.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode
      iex> |> Enum.take(2)
      [ok: [\"a\",\"b\",\"c\"], ok: [\"d\",\"e\",\"f\"]]

  Errors will show up as error tuples:

      iex> \"../test/fixtures/docs/escape-errors.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode
      iex> |> Enum.take(2)
      [
        ok: [\"a\",\"b\",\"c\"],
        error: "Escape sequence started on line 2 near \\"d,e,f\\n\\" did \
  not terminate.\\n\\nEscape sequences are allowed to span up to 1000 lines. \
  This threshold avoids collecting the whole file into memory when an escape \
  sequence does not terminate. You can change it using the escape_max_lines \
  option: https://hexdocs.pm/csv/CSV.html#decode/2"
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode(separator: ?;, headers: true)
      iex> |> Enum.take(2)
      [
        ok: %{\"a\" => \"c\", \"b\" => \"d\"},
        ok: %{\"a\" => \"e\", \"b\" => \"f\"}
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode(separator: ?;, headers: [:x, :y])
      iex> |> Enum.take(2)
      [
        ok: %{:x => \"a\", :y => \"b\"},
        ok: %{:x => \"c\", :y => \"d\"}
      ]

  """

  def decode(stream, options \\ []) do
    stream |> preprocess(options) |> Decoder.decode(options) |> inline_errors!(options)
  end

  @doc """
  Decode a stream of comma-separated lines into a stream of tuples. Errors
  when decoding will get raised immediately.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
    * `:strip_fields` – When set to true, will strip whitespace from cells.
      Defaults to false.
    * `:preprocessor` – Which preprocessor to use:
        :lines (default) -> Will preprocess line by line input respecting
        escape sequences
        :none -> Will not preprocess input and expects line by line input
        with multiple line escape sequences aggregated to one line
    * `:escape_max_lines` – How many lines to maximally aggregate for multiline
      escapes. Defaults to a 1000.
    * `:validate_row_length` – If set to `false`, will disable validation for
      row length. This will allow for rows with variable length. Defaults to
      `true`
    * `:num_workers` – The number of parallel operations to run when
      producing the stream.
    * `:worker_work_ratio` – The available work per worker, defaults to 5.
      Higher rates will mean more work sharing, but might also lead to work
      fragmentation slowing down the queues.
    * `:headers`     – When set to `true`, will take the first row of the csv
      and use it as header values.
      When set to a list, will use the given list as header values.
      When set to `false` (default), will use no header values.
      When set to anything but `false`, the resulting rows in the matrix will
      be maps instead of lists.

  ## Examples

  Convert a filestream into a stream of rows in order of the given stream:

      iex> \"../test/fixtures/docs/valid.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode!
      iex> |> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Errors will be raised:

      iex> \"../test/fixtures/docs/row-length-errors.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode!
      iex> |> Enum.take(2)
      ** (CSV.RowLengthError) Row has length 3 - expected length 2 on line 2

  Map an existing stream of lines separated by a token to a stream of rows
  with a header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode!(separator: ?;, headers: true)
      iex> |> Enum.take(2)
      [
        %{\"a\" => \"c\", \"b\" => \"d\"},
        %{\"a\" => \"e\", \"b\" => \"f\"}
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a given header row:

      iex> [\"a;b\",\"c;d\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode!(separator: ?;, headers: [:x, :y])
      iex> |> Enum.take(2)
      [
        %{:x => \"a\", :y => \"b\"},
        %{:x => \"c\", :y => \"d\"}
      ]

  """

  def decode!(stream, options \\ []) do
    stream |> preprocess(options) |> Decoder.decode(options) |> raise_errors!(options)
  end

  defp preprocess(stream, options) do
    case options |> Keyword.get(:preprocessor) do
      :none ->
        stream |> Preprocessing.None.process(options)

      _ ->
        stream |> Preprocessing.Lines.process(options)
    end
  end

  defp raise_errors!(stream, options) do
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream |> Stream.map(&yield_or_raise!(&1, escape_max_lines))
  end

  defp yield_or_raise!({:error, EscapeSequenceError, escape_sequence, index}, escape_max_lines) do
    raise EscapeSequenceError,
      escape_sequence: escape_sequence,
      line: index + 1,
      escape_max_lines: escape_max_lines
  end

  defp yield_or_raise!({:error, StrayQuoteError, field, index}, _) do
    raise StrayQuoteError,
      field: field,
      line: index + 1
  end

  defp yield_or_raise!({:error, mod, message, index}, _) do
    raise mod, message: message, line: index + 1
  end

  defp yield_or_raise!({:ok, row}, _), do: row

  defp inline_errors!(stream, options) do
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream |> Stream.map(&yield_or_inline!(&1, escape_max_lines))
  end

  defp yield_or_inline!({:error, EscapeSequenceError, escape_sequence, index}, escape_max_lines) do
    {:error,
     EscapeSequenceError.exception(
       escape_sequence: escape_sequence,
       line: index + 1,
       escape_max_lines: escape_max_lines
     ).message}
  end

  defp yield_or_inline!({:error, StrayQuoteError, field, index}, _) do
    {:error,
     StrayQuoteError.exception(
       field: field,
       line: index + 1
     ).message}
  end

  defp yield_or_inline!({:error, errormod, message, index}, _) do
    {:error, errormod.exception(message: message, line: index + 1).message}
  end

  defp yield_or_inline!(value, _), do: value

  @doc """
  Encode a table stream into a stream of RFC 4180 compliant CSV lines for
  writing to a file or other IO.

  ## Options

  These are the options:

    * `:separator`   – The separator token to use, defaults to `?,`.
    Must be a codepoint (syntax: ? + (your separator)).
    * `:delimiter`   – The delimiter token to use, defaults to `\\r\\n`.
    Must be a string.

  ## Examples

  Convert a stream of rows with cells into a stream of lines:

      iex> [~w(a b), ~w(c d)]
      iex> |> CSV.encode
      iex> |> Enum.take(2)
      [\"a,b\\r\\n\", \"c,d\\r\\n\"]

  Convert a stream of rows with cells with escape sequences into a stream of
  lines:

      iex> [[\"a\\nb\", \"\\tc\"], [\"de\", \"\\tf\\\"\"]]
      iex> |> CSV.encode(separator: ?\\t, delimiter: \"\\n\")
      iex> |> Enum.take(2)
      [\"\\\"a\\nb\\\"\\t\\\"\\tc\\\"\\n\", \"de\\t\\\"\\tf\\\"\\\"\\\"\\n\"]
  """

  def encode(stream, options \\ []) do
    Encoder.encode(stream, options)
  end
end
