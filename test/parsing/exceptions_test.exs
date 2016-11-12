defmodule ParsingTests.ExceptionsTest do
  use ExUnit.Case

  alias CSV.Parser
  alias CSV.Parser.SyntaxError

  test "raises a syntax error when given an invalid sequence of tokens" do
    parsed = Enum.map [
      {[
          {:double_quote, "\""},
          {:delimiter, "\r\n"},
          {:content, "c"},
          {:separator, ","},
          {:content, "d"},
        ], 1}, {[
          {:content, "a"},
          {:separator, ","},
          {:double_quote, "\""},
          {:content, "b"},
          {:double_quote, "\""},
          {:double_quote, "\""},
          {:content, "c"},
          {:separator, ","},
          {:double_quote, "\""},
        ], 2}
    ], &Parser.parse/1

    assert parsed == [
      {:error, SyntaxError, "Unterminated escape sequence near '\r\nc,d'", 1},
      {:ok, ["a", "b\"c,"], 2},
    ]
  end

  test "raises a syntax error when halted in an escape sequence" do
    parsed = Enum.map [
      {[
          {:content, "a"},
          {:separator, ","},
          {:double_quote, "\""},
          {:content, "b"},
          {:double_quote, "\""},
          {:double_quote, "\""},
          {:content, "c"},
          {:separator, ","},
          {:double_quote, "\""},
        ], 1}, {[
          {:double_quote, "\""},
          {:delimiter, "\r\n"},
          {:content, "c"},
          {:separator, ","},
          {:content, "d"},
        ], 2}
    ], &Parser.parse/1

    assert parsed == [
      {:ok, ["a", "b\"c,"], 1},
      {:error, SyntaxError, "Unterminated escape sequence near '\r\nc,d'", 2},
    ]
  end

  test "the parser propagates errors" do
    parsed = Enum.map [
      {[
          {:content, "a"},
          {:separator, ","},
          {:double_quote, "\""},
          {:content, "b"},
          {:double_quote, "\""},
          {:double_quote, "\""},
          {:content, "c"},
          {:separator, ","},
          {:double_quote, "\""},
        ], 1}, {:error, RuntimeError, "MESSAGE", 2}
    ], &Parser.parse/1

    assert parsed == [
      {:ok, ["a", "b\"c,"], 1},
      {:error, RuntimeError, "MESSAGE", 2},
    ]
  end
end
