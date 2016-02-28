defmodule CSV.Lexer do
  use CSV.Defaults
  alias CSV.Lexer.EncodingError

  @moduledoc ~S"""
  RFC 4180 compatible CSV lexer. Lexes tokens and sends them to the parser process.
  """

  @doc """
  Lexes strings received from a sender (the decoder) and sends the resulting tokens to
  the parser process / the receiver.

  ## Options

  Options get transferred from the decoder. They are:

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint.
  """

  def lex({ line, index }, options \\ []) when is_list(options) do
    separator = options |> Keyword.get(:separator, @separator)

    case String.valid?(line) do
      false -> { :error, EncodingError, "Invalid encoding", index }
      true -> lex(line, index, separator)
    end
  end

  defp lex(line, index, separator) do
    case lex([], nil, line, separator) do
      { :ok, tokens } -> { :ok, tokens, index }
    end
  end

  defp lex(tokens, { :delimiter, value }, << @newline :: utf8 >> <> tail, separator) do
    lex(tokens, { :delimiter, value <> << @newline :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, current_token, << @newline :: utf8 >> <> tail, separator) do
    lex(tokens |> add_token(current_token), { :delimiter, << @newline :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, current_token, << @carriage_return :: utf8 >> <> tail, separator) do
    lex(tokens |> add_token(current_token), { :delimiter, << @carriage_return :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, current_token, << @double_quote :: utf8 >> <> tail, separator) do
    lex(tokens |> add_token(current_token), { :double_quote, << @double_quote :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, current_token, << head :: utf8 >> <> tail, separator) when head == separator do
    lex(tokens |> add_token(current_token), { :separator, << separator :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, { :content, value }, << head :: utf8 >> <> tail, separator) do
    lex(tokens, { :content, value <> << head :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, nil, << head :: utf8 >> <> tail, separator) do
    lex(tokens, { :content, << head :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, current_token, << head :: utf8 >> <> tail, separator) do
    lex(tokens |> add_token(current_token), { :content, << head :: utf8 >> }, tail, separator)
  end
  defp lex(tokens, current_token, "", _) do
    { :ok, tokens |> add_token(current_token) }
  end

  defp add_token(tokens, nil) do
    tokens
  end
  defp add_token(tokens, token) do
    tokens ++ [token]
  end
end
