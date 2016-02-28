defmodule ParserTest do
  use ExUnit.Case

  alias CSV.Parser
  alias CSV.Parser.SyntaxError

  test "turns a sequence of tokens into a csv matrix" do
    parsed = Enum.map [
      {[
          {:content, "a"},
          {:separator, ","},
          {:content, "b"},
          {:delimiter, "\r\n"},
        ], 1}, {[
          {:content, "c"},
          {:separator, ","},
          {:content, "d"},
        ], 2}
    ], &Parser.parse/1

    assert parsed == [
      {:ok, ~w(a b), 1},
      {:ok, ~w(c d), 2}
    ]
  end

  test "turns a sequence of tokens into a csv matrix and strips cells" do
    parsed = Enum.map [
      {[
          {:content, " "},
          {:content, " "},
          {:content, "a"},
          {:content, " "},
          {:separator, ","},
          {:content, "b"},
          {:delimiter, "\r\n"},
        ], 1}, {[
          {:content, " "},
          {:content, "c"},
          {:separator, ","},
          {:content, " "},
          {:content, "d"},
          {:content, " "},
        ], 2}
    ], &Parser.parse(&1, strip_cells: true)

    assert parsed == [
      {:ok, ~w(a b), 1},
      {:ok, ~w(c d), 2}
    ]
  end

  test "turns a sequence of tokens with escape sequences into a csv matrix" do
    parsed = Enum.map [
      {[
          {:content, "a"},
          {:separator, ","},
          {:double_quote, "\""},
          {:content, "b"},
          {:delimiter, "\r\n"},
          {:content, "c"},
          {:separator, ","},
          {:double_quote, "\""},
        ], 1}, {[
          {:delimiter, "\r\n"},
          {:content, "c"},
          {:separator, ","},
          {:content, "d"},
        ], 2}
    ], &Parser.parse/1

    assert parsed == [
      {:ok, ["a", "b\r\nc,"], 1},
      {:ok, ["c", "d"], 2}
    ]
  end

  test "manages escaped double quotes inside double quoted fields according to RFC 4180" do
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
          {:delimiter, "\r\n"},
          {:content, "c"},
          {:separator, ","},
          {:content, "d"},
        ], 2}
    ], &Parser.parse/1

    assert parsed == [
      {:ok, ["a", "b\"c,"], 1},
      {:ok, ["c", "d"], 2}
    ]
  end

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
