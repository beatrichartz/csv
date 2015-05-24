defmodule CSV.Lexer do
  use CSV.Defaults

  @moduledoc ~S"""
  RFC 4180 compatible CSV lexer. Lexes tokens and sends them to the parser process.
  """

  @doc """
  Lexes strings received from a sender (the decoder) and sends the resulting tokens to
  the parser process / the receiver.

  ## Options

  Options get transferred from the decoder. They are:

    * `:separator`   – The separator token to use, defaults to ",". Can only be a single token.
  """

  def lex_into(receiver, options \\ []) do
    receive do
      { :halt, value } ->
        send receiver, {:halt, value}
      { index, line } ->
        lex(index, line, receiver, options)
        lex_into(receiver, options)
    end
  end

  defp lex(index, string, receiver, options) when is_list(options) do
    separator = options |> Keyword.get(:separator, @separator)

    lex(index, string, receiver, {:start, index}, separator)
  end

  defp lex(index, @newline <> tail, receiver, current_token, separator) do
    case current_token do
      {:delimiter, value} -> lex(index, tail, receiver, {:delimiter, value <> @newline}, separator)
      _ ->
        emit_token!(current_token, receiver)
        lex(index, tail, receiver, {:delimiter, @newline}, separator)
    end
  end

  defp lex(index, @carriage_return <> tail, receiver, current_token, separator) do
    case current_token do
      {:delimiter, value} -> lex(index, tail, {:delimiter, receiver, value <> @carriage_return}, separator)
      _ ->
        emit_token!(current_token, receiver)
        lex(index, tail, receiver, {:delimiter, @carriage_return}, separator)
    end
  end

  defp lex(index, @double_quote <> tail, receiver, current_token, separator) do
    emit_token!(current_token, receiver)
    lex(index, tail, receiver, {:double_quote, @double_quote}, separator)
  end

  defp lex(index, << head :: utf8 >> <> tail, receiver, current_token, separator) do
    case << head :: utf8 >> do
      ^separator ->
        emit_token!(current_token, receiver)
        lex(index, tail, receiver, {:separator, separator}, separator)

      _ -> case current_token do
             {:content, value} ->
              lex(index, tail, receiver, {:content, value <> << head :: utf8 >>}, separator)
             _ ->
               emit_token!(current_token, receiver)
               lex(index, tail, receiver, {:content, << head :: utf8 >>}, separator)
           end
    end
  end

  defp lex(index, "", receiver, current_token, _) do
    emit_token!(current_token, receiver)
    emit_token!({:end, index}, receiver)
  end

  defp lex(_, nil, _, _, _) do
  end

  defp emit_token!(nil, _) do
  end

  defp emit_token!(token, receiver) do
    send receiver, token
  end

end
