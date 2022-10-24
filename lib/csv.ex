defmodule CSV do
  use CSV.Defaults

  alias CSV.Decoding.Decoder
  alias CSV.Encoding.Encoder

  @moduledoc ~S"""
  RFC 4180 compliant CSV parsing and encoding for Elixir. Allows to specify
  other separators, so it could also be named: TSV, but it isn't.
  """

  @doc """
  Decode a stream of comma-separated lines into a stream of tuples. Decoding
  errors will be inlined into the stream.

  ## Options

  These are the options:

  * `:separator`           – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
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
  * `:unescape_formulas       – When set to `true`, will remove formula escaping 
      inserted to prevent [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

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
        error: "Escape sequence started on line 2:\\n\\n\\"d,e,f\\n\\n\
  did not terminate before the stream halted. Parsing will continue on line 3.\\n"
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a header row:

      iex> [\"a;b\\n\",\"c;d\\n\", \"e;f\\n\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode(separator: ?;, headers: true)
      iex> |> Enum.take(2)
      [
        ok: %{\"a\" => \"c\", \"b\" => \"d\"},
        ok: %{\"a\" => \"e\", \"b\" => \"f\"}
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a given header row:

      iex> [\"a;b\\n\",\"c;d\\n\", \"e;f\\n\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode(separator: ?;, headers: [:x, :y])
      iex> |> Enum.take(2)
      [
        ok: %{:x => \"a\", :y => \"b\"},
        ok: %{:x => \"c\", :y => \"d\"}
      ]

  """

  @type decode_options ::
          {:separator, char}
          | {:field_transform, (String.t() -> String.t())}
          | {:headers, [String.t() | atom()] | boolean()}
          | {:unescape_formulas, boolean()}
          | {:validate_row_length, boolean()}

  @spec decode(Enumerable.t(), [decode_options()]) :: Enumerable.t()
  def decode(stream, options \\ []) do
    stream |> Decoder.decode(options) |> inline_errors!(options)
  end

  @doc """
  Decode a stream of comma-separated lines into a stream of tuples. Errors
  when decoding will get raised immediately.

  ## Options

  These are the options:

  * `:separator`           – The separator token to use, defaults to `?,`.
      Must be a codepoint (syntax: ? + (your separator)).
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
      length. Will raise an error if validation fails. Defaults to `false`.
  * `:escape_formulas       – When set to `true`, will remove formula escaping 
  ## Examples

  Convert a filestream into a stream of rows in order of the given stream:

      iex> \"../test/fixtures/docs/valid.csv\"
      iex> |> Path.expand(__DIR__)
      iex> |> File.stream!
      iex> |> CSV.decode!
      iex> |> Enum.take(2)
      [[\"a\",\"b\",\"c\"], [\"d\",\"e\",\"f\"]]

  Map an existing stream of lines separated by a token to a stream of rows
  with a header row:

      iex> [\"a;b\\n\",\"c;d\\n\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode!(separator: ?;, headers: true)
      iex> |> Enum.take(2)
      [
        %{\"a\" => \"c\", \"b\" => \"d\"},
        %{\"a\" => \"e\", \"b\" => \"f\"}
      ]

  Map an existing stream of lines separated by a token to a stream of rows
  with a given header row:

      iex> [\"a;b\\n\",\"c;d\\n\", \"e;f\"]
      iex> |> Stream.map(&(&1))
      iex> |> CSV.decode!(separator: ?;, headers: [:x, :y])
      iex> |> Enum.take(2)
      [
        %{:x => \"a\", :y => \"b\"},
        %{:x => \"c\", :y => \"d\"}
      ]

  Trim each field:

      iex> [\" a , b   \\n\",\" c   ,   d \\n\"]
      ...> |> Stream.map(&(&1))
      ...> |> CSV.decode(field_transform: &String.trim/1)
      ...> |> Enum.take(2)
      [ok: [\"a\", \"b\"], ok: [\"c\", \"d\"]]

  Replace invalid codepoints:
      
      iex> \"../test/fixtures/broken-encoding.csv\"
      ...> |> Path.expand(__DIR__)
      ...> |> File.stream!()
      ...> |> CSV.decode(field_transform: fn field ->
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

  """

  @spec decode!(Enumerable.t(), [decode_options()]) :: Enumerable.t()
  def decode!(stream, options \\ []) do
    stream |> Decoder.decode(options) |> raise_errors!(options)
  end

  defp raise_errors!(stream, options) do
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream |> Stream.map(&yield_or_raise!(&1, escape_max_lines))
  end

  defp yield_or_raise!({:error, mod, args}, _) do
    raise mod, args ++ [mode: :strict]
  end

  defp yield_or_raise!({:ok, row}, _), do: row

  defp inline_errors!(stream, options) do
    escape_max_lines = options |> Keyword.get(:escape_max_lines, @escape_max_lines)

    stream |> Stream.map(&yield_or_inline!(&1, escape_max_lines))
  end

  defp yield_or_inline!({:error, mod, args}, _) do
    {:error, mod.exception(args ++ [mode: :normal]).message}
  end

  defp yield_or_inline!(value, _), do: value

  @doc """
  Encode a table stream into a stream of RFC 4180 compliant CSV lines for
  writing to a file or other IO.

  ## Options

  These are the options:

    * `:separator`              – The separator token to use, defaults to `?,`.
    Must be a codepoint (syntax: ? + (your separator)).
    * `:delimiter`              – The delimiter token to use, defaults to `\\r\\n`.
    Must be a string.
    * `:escape_formulas         – When set to `true`, will escape formulas
    to prevent [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).

  ## Examples

  Convert a stream of rows with fields into a stream of lines:

      iex> [~w(a b), ~w(c d)]
      iex> |> CSV.encode
      iex> |> Enum.take(2)
      [\"a,b\\r\\n\", \"c,d\\r\\n\"]

  Convert a stream of rows with fields with escape sequences into a stream of
  lines:

      iex> [[\"a\\nb\", \"\\tc\"], [\"de\", \"\\tf\\\"\"]]
      iex> |> CSV.encode(separator: ?\\t, delimiter: \"\\n\")
      iex> |> Enum.take(2)
      [\"\\\"a\\nb\\\"\\t\\\"\\tc\\\"\\n\", \"de\\t\\\"\\tf\\\"\\\"\\\"\\n\"]

  Convert a stream of rows with fields with formulas into a stream of
  lines:

      iex> [~w(@a =b), ~w(-c +d)]
      iex> |> CSV.encode(escape_formulas: true)
      iex> |> Enum.take(2)
      [\"\\\"'@a\\\",\\\"'=b\\\"\\r\\n\", \"\\\"'-c\\\",\\\"'+d\\\"\\r\\n\"]
  """

  @type encode_options ::
          {:separator, char}
          | {:delimiter, String.t()}
          | {:escape_formulas, boolean()}

  @spec encode(Enumerable.t(), [encode_options()]) :: Enumerable.t()
  def encode(stream, options \\ []) do
    Encoder.encode(stream, options)
  end
end
