defmodule CSV.Decoding.Parser do
  alias CSV.EscapeSequenceError
  alias CSV.StrayQuoteError

  @moduledoc ~S"""
  The CSV Parser module - parses tokens coming from the lexer and parses them
  into a row of fields.
  """

  @doc """
  Parses tokens by receiving them from a sender / lexer and sending them to
  the given receiver process (the decoder).

  ## Options

  Options get transferred from the decoder. They are:

    * `:strip_fields` – When set to true, will strip whitespace from fields.
      Defaults to false.
    * `:raw_line_on_error` – When set to true, raw csv line will be returned on
      error tuples. Defaults to false.
  """

  def parse(message, options \\ [])

  def parse({tokens, index}, options), 
    do: parse({tokens, "", index}, options)

  def parse({tokens, raw_line, index}, options) do
    case parse([], "", tokens, :unescaped, options) do
      {:ok, row} -> {:ok, row, index}
      {:error, type, message} -> 
        {:error, type, message, index}
        |> append_raw_line?(raw_line, options)
    end
  end

  def parse({:error, mod, message, index}, _) do
    {:error, mod, message, index}
  end

  defp parse(row, field, [token | tokens], :inline_quote, options) do
    case token do
      {:double_quote, content} ->
        parse(row, field <> content, tokens, :unescaped, options)

      _ ->
        {:error, StrayQuoteError, field}
    end
  end

  defp parse(row, field, [token | tokens], :inline_quote_in_escaped, options) do
    case token do
      {:double_quote, content} ->
        parse(row, field <> content, tokens, :escaped, options)

      {:separator, _} ->
        parse(row ++ [field |> strip(options)], "", tokens, :unescaped, options)

      {:delimiter, _} ->
        parse(row, field, tokens, :unescaped, options)

      _ ->
        {:error, StrayQuoteError, field}
    end
  end

  defp parse(row, field, [token | tokens], :escaped, options) do
    case token do
      {:double_quote, _} ->
        parse(row, field, tokens, :inline_quote_in_escaped, options)

      {_, content} ->
        parse(row, field <> content, tokens, :escaped, options)
    end
  end

  defp parse(_, field, [], :escaped, _) do
    {:error, EscapeSequenceError, field}
  end

  defp parse(_, field, [], :inline_quote, _) do
    {:error, StrayQuoteError, field}
  end

  defp parse(row, "", [token | tokens], :unescaped, options) do
    case token do
      {:content, content} ->
        parse(row, content, tokens, :unescaped, options)

      {:separator, _} ->
        parse(row ++ [""], "", tokens, :unescaped, options)

      {:delimiter, _} ->
        parse(row, "", tokens, :unescaped, options)

      {:double_quote, _} ->
        parse(row, "", tokens, :escaped, options)
    end
  end

  defp parse(row, field, [token | tokens], :unescaped, options) do
    case token do
      {:content, content} ->
        parse(row, field <> content, tokens, :unescaped, options)

      {:separator, _} ->
        parse(row ++ [field |> strip(options)], "", tokens, :unescaped, options)

      {:delimiter, _} ->
        parse(row, field, tokens, :unescaped, options)

      {:double_quote, _} ->
        parse(row, field, tokens, :inline_quote, options)
    end
  end

  defp parse(row, field, [], :inline_quote_in_escaped, options) do
    {:ok, row ++ [field |> strip(options)]}
  end

  defp parse(row, field, [], :unescaped, options) do
    {:ok, row ++ [field |> strip(options)]}
  end

  defp strip(field, options) do
    strip_fields = options |> Keyword.get(:strip_fields, false)

    case strip_fields do
      true -> field |> String.trim()
      _ -> field
    end
  end

  @doc false
  def append_raw_line?(error_tuple, raw_line, options) do
    raw_line_on_error = options |> Keyword.get(:raw_line_on_error, false)
    do_append_raw_line?(error_tuple, raw_line, raw_line_on_error)
  end
  defp do_append_raw_line?(error_tuple, raw_line, true = _raw_line_on_error),
    do: Tuple.append(error_tuple, raw_line)
  defp do_append_raw_line?(error_tuple, _raw_line, _raw_line_on_error), do: error_tuple
end
