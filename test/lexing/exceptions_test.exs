defmodule LexingTests.ExceptionsTest do
  use ExUnit.Case
  alias CSV.Lexer
  alias CSV.Lexer.EncodingError

  test "raises a syntax error when the string is not valid" do
    lexed = Lexer.lex({<<191>>, 1})
    assert lexed == {:error, EncodingError, "Invalid encoding", 1}
  end
end
