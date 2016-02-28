defmodule LexerTest do
  use ExUnit.Case
  alias CSV.Lexer
  alias CSV.Lexer.EncodingError

  test "parses strings into a list of token tuples" do
    lexed = Lexer.lex({"a,be\r\n", 11})

    assert lexed == {:ok, [
        {:content, "a"},
        {:separator, ","},
        {:content, "be"},
        {:delimiter, "\r\n"}
      ], 11}
  end

  test "parse escape sequences into a list of token tuples" do
    lexed = Lexer.lex({"\"c,d", 11})
    assert lexed == {:ok, [
        {:double_quote, "\""},
        {:content, "c"},
        {:separator, ","},
        {:content, "d"}
      ], 11}
  end

  test "parses strings into a list of token tuples with quotes" do
    lexed = Lexer.lex({"a,\"be\"\"\r\n", 1})

    assert lexed == {:ok, [
        {:content, "a"},
        {:separator, ","},
        {:double_quote, "\""},
        {:content, "be"},
        {:double_quote, "\""},
        {:double_quote, "\""},
        {:delimiter, "\r\n"}
      ], 1}
  end

  test "raises a syntax error when the string is not valid" do
    lexed = Lexer.lex({<<191>>, 1})
    assert lexed == {:error, EncodingError, "Invalid encoding", 1}
  end
end
