defmodule CSV.Decoding.Lexer do
  use CSV.Defaults
  alias CSV.EncodingError

  @moduledoc ~S"""
  RFC 4180 compatible CSV lexer. Lexes tokens and sends them to the parser
  process.
  """

  @doc """
  Lexes strings received from a sender (the decoder) and sends the resulting
  tokens to the parser process / the receiver.

  ## Options

  Options get transferred from the decoder. They are:

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a
      codepoint.

    * `:replacement`    – The replacement string to use where lines have bad
      encoding. Defaults to `nil`, which disables replacement.
  """

  def lex({line, index}, options \\ []) when is_list(options) do
    separator = options |> Keyword.get(:separator, @separator)
    replacement = options |> Keyword.get(:replacement, @replacement)
    escape_formulas = options |> Keyword.get(:escape_formulas, @escape_formulas)

    case String.valid?(line) do
      false ->
        if replacement do
          replace_bad_encoding(line, replacement) |> lex(index, separator, escape_formulas)
        else
          {:error, EncodingError, "Invalid encoding", index}
        end

      true ->
        lex(line, index, separator, escape_formulas)
    end
  end

  defp lex(line, index, separator, escape_formulas) do
    case lex([], nil, line, separator, escape_formulas) do
      {:ok, tokens} -> {:ok, tokens, index}
    end
  end

  defp lex(tokens, {:delimiter, value}, <<@newline::utf8>> <> tail, separator, escape_formulas) do
    lex(tokens, {:delimiter, value <> <<@newline::utf8>>}, tail, separator, escape_formulas)
  end

  defp lex(tokens, current_token, <<@newline::utf8>> <> tail, separator, escape_formulas) do
    lex(
      tokens |> add_token(current_token),
      {:delimiter, <<@newline::utf8>>},
      tail,
      separator,
      escape_formulas
    )
  end

  defp lex(tokens, current_token, <<@carriage_return::utf8>> <> tail, separator, escape_formulas) do
    lex(
      tokens |> add_token(current_token),
      {:delimiter, <<@carriage_return::utf8>>},
      tail,
      separator,
      escape_formulas
    )
  end

  defp lex(tokens, current_token, <<@double_quote::utf8>> <> tail, separator, escape_formulas) do
    lex(
      tokens |> add_token(current_token),
      {:double_quote, <<@double_quote::utf8>>},
      tail,
      separator,
      escape_formulas
    )
  end

  defp lex(tokens, current_token, <<head::utf8>> <> tail, separator, escape_formulas)
       when head == separator do
    lex(
      tokens |> add_token(current_token),
      {:separator, <<separator::utf8>>},
      tail,
      separator,
      escape_formulas
    )
  end

  for start <- @escape_formula_start do
    defp lex(tokens, current_token, "'#{unquote(start)}" <> tail, separator, true) do
      lex(tokens, current_token, unquote(start) <> tail, separator, true)
    end
  end

  defp lex(tokens, {:content, value}, <<head::utf8>> <> tail, separator, escape_formulas) do
    lex(tokens, {:content, value <> <<head::utf8>>}, tail, separator, escape_formulas)
  end

  defp lex(tokens, nil, <<head::utf8>> <> tail, separator, escape_formulas) do
    lex(tokens, {:content, <<head::utf8>>}, tail, separator, escape_formulas)
  end

  defp lex(tokens, current_token, <<head::utf8>> <> tail, separator, escape_formulas) do
    lex(
      tokens |> add_token(current_token),
      {:content, <<head::utf8>>},
      tail,
      separator,
      escape_formulas
    )
  end

  defp lex(tokens, current_token, "", _, _) do
    {:ok, tokens |> add_token(current_token)}
  end

  defp add_token(tokens, nil) do
    tokens
  end

  defp add_token(tokens, token) do
    tokens ++ [token]
  end

  defp replace_bad_encoding(line, replacement) do
    line
    |> String.codepoints()
    |> Enum.map(fn codepoint -> if String.valid?(codepoint), do: codepoint, else: replacement end)
    |> Enum.join()
  end
end
