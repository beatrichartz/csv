defmodule LexingTests.BaselineTest do
  use ExUnit.Case
  alias CSV.Decoding.Lexer

  doctest Lexer

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
end
