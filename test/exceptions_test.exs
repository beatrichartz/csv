defmodule ExceptionsTest do
  use ExUnit.Case

  alias CSV.EncodingError
  alias CSV.EscapeSequenceError
  alias CSV.StrayQuoteError

  test "exception messaging about encoding errors" do
    exception = EncodingError.exception(line: 1, message: "BAD ENCODING")

    assert exception.message == "BAD ENCODING on line 1"
  end

  test "exception messaging about unfinished escape sequences" do
    exception =
      EscapeSequenceError.exception(
        line: 1,
        escape_sequence: "SEQUENCE END",
        escape_max_lines: 2
      )

    assert exception.message ==
             "Escape sequence started on line 1 near \"SEQUENCE E\" did not terminate.\n\n" <>
               "Escape sequences are allowed to span up to 2 lines. This threshold avoids " <>
               "collecting the whole file into memory when an escape sequence does not terminate. " <>
               "You can change it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2"
  end

  test "exception messaging about stray quote errors" do
    exception = StrayQuoteError.exception(line: 1, field: "THIS")

    assert exception.message == "Stray quote on line 1 near \"THIS\""
  end
end
