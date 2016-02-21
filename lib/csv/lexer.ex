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

    * `:separator`   – The separator token to use, defaults to `?,`. Must be a codepoint.
  """

  def lex_into(receiver, options \\ []) do
    receive do
      { :halt, value } ->
        send receiver, {:halt, value}
      { index, line } ->
        case String.valid?(line) do
          true -> 
            lex(index, line, receiver, options)
            lex_into(receiver, options)
          false ->
            send receiver, {:lexer_error, { index, "Invalid encoding for utf-8."}}
        end
    end
  end

  defp lex(index, string, receiver, options) when is_list(options) do
    separator = options |> Keyword.get(:separator, @separator)

    lex(index, string, receiver, {:start, index}, separator)
  end

  defp lex(index, << @newline :: utf8 >> <> tail, receiver, current_token, separator) do
    case current_token do
      {:delimiter, value} -> lex(index, tail, receiver, {:delimiter, value <> << @newline :: utf8 >>}, separator)
      _ ->
        emit_token!(current_token, receiver)
        lex(index, tail, receiver, {:delimiter, << @newline :: utf8 >>}, separator)
    end
  end

  defp lex(index, << @carriage_return :: utf8 >> <> tail, receiver, current_token, separator) do
    emit_token!(current_token, receiver)
    lex(index, tail, receiver, {:delimiter, << @carriage_return :: utf8 >>}, separator)
  end

  defp lex(index, << @double_quote :: utf8 >> <> tail, receiver, current_token, separator) do
    emit_token!(current_token, receiver)
    lex(index, tail, receiver, {:double_quote, << @double_quote :: utf8 >>}, separator)
  end

  defp lex(index, << head :: utf8 >> <> tail, receiver, current_token, separator) do
    case head do
      ^separator ->
        emit_token!(current_token, receiver)
        lex(index, tail, receiver, {:separator, << separator :: utf8 >>}, separator)

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
