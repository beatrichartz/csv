defmodule ParserTest do
  use ExUnit.Case
  alias CSV.Parser, as: Parser

  setup do
    test_pid = self
    parser_pid = spawn_link(fn ->
      Parser.parse_into(test_pid)
    end)

    {:ok, parser_pid: parser_pid}
  end

  test "turns a sequence of tokens into a csv matrix", context do
    Enum.each [
      {:start, 1},
      {:content, "a"},
      {:separator, ","},
      {:content, "b"},
      {:delimiter, "\r\n"},
      {:end, 1},
      {:start, 2},
      {:content, "c"},
      {:separator, ","},
      {:content, "d"},
      {:end, 2}
    ], fn(token) ->
      send(context[:parser_pid], token)
    end

    assert_receive {:row, {1, ~w(a b)}}, 10
    assert_receive {:row, {2, ~w(c d)}}, 10
  end

  test "turns a sequence of tokens with escape sequences into a csv matrix", context do
    Enum.each [
      {:start, 1},
      {:content, "a"},
      {:separator, ","},
      {:double_quote, "\""},
      {:content, "b"},
      {:delimiter, "\r\n"},
      {:content, "c"},
      {:separator, ","},
      {:double_quote, "\""},
      {:end, 1},
      {:start, 2},
      {:delimiter, "\r\n"},
      {:content, "c"},
      {:separator, ","},
      {:content, "d"},
      {:end, 2}
    ], fn(token) ->
      send(context[:parser_pid], token)
    end

    assert_receive {:row, {1, ["a", "b\r\nc,"]}}, 10
    assert_receive {:row, {2, ["c", "d"]}}, 10
  end

  test "manages escaped double quotes inside double quoted fields according to RFC 4180", context do
    Enum.each [
      {:start, 1},
      {:content, "a"},
      {:separator, ","},
      {:double_quote, "\""},
      {:content, "b"},
      {:double_quote, "\""},
      {:double_quote, "\""},
      {:content, "c"},
      {:separator, ","},
      {:double_quote, "\""},
      {:end, 1},
      {:start, 2},
      {:delimiter, "\r\n"},
      {:content, "c"},
      {:separator, ","},
      {:content, "d"},
      {:end, 2}
    ], fn(token) ->
      send(context[:parser_pid], token)
    end

    assert_receive {:row, {1, ["a", "b\"c,"]}}, 10
    assert_receive {:row, {2, ["c", "d"]}}, 10
  end

  test "raises a syntax error when given an invalid sequence of tokens", context do
    Enum.each [
      {:start, 1},
      {:content, "a"},
      {:separator, ","},
      {:double_quote, "\""},
      {:content, "b"},
      {:double_quote, "\""},
      {:double_quote, "\""},
      {:content, "c"},
      {:separator, ","},
      {:double_quote, "\""},
      {:end, 1},
      {:start, 2},
      {:double_quote, "\""},
      {:delimiter, "\r\n"},
      {:content, "c"},
      {:separator, ","},
      {:content, "d"},
      {:end, 2}
    ], fn(token) ->
      send(context[:parser_pid], token)
    end

    assert_receive {:error, {2, "Unterminated escape sequence."}}, 10
  end


end
