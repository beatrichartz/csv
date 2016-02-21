defmodule LexerTest do
  use ExUnit.Case
  alias CSV.Lexer, as: Lexer

  test "parses strings into a list of token tuples and emits them" do
    test_pid = self
    lexer_pid = spawn_link fn ->
      Lexer.lex_into(test_pid)
    end

    send lexer_pid, {1, "a,be\r\n"}
    send lexer_pid, {2, "c,d"}

    assert_receive {:start, 1}, 1
    assert_receive {:content, "a"}, 1
    assert_receive {:separator, ","}, 1
    assert_receive {:content, "be"}, 1
    assert_receive {:delimiter, "\r\n"}, 1
    assert_receive {:end, 1}, 1
    assert_receive {:start, 2}, 1
    assert_receive {:content, "c"}, 1
    assert_receive {:separator, ","}, 1
    assert_receive {:content, "d"}, 1
    assert_receive {:end, 2}, 1
  end
end
