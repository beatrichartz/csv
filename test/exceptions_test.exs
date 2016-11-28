defmodule ExceptionsTest do
  use ExUnit.Case

  alias CSV.EscapeSequenceError

  test "exception messaging about unfinished escape sequences" do
    exception = EscapeSequenceError.
                  exception(
                    line: 1,
                    escape_sequence: "SEQUENCE END",
                    num_escaped_lines: 0,
                    escape_max_lines: 2
                  )
    assert exception.message ==
      "Escape sequence started on line 1 near \"SEQUENCE E\" did not terminate"
  end

  test "exception messaging about unfinished escape sequences spanning multiple lines" do
    exception = EscapeSequenceError.
                  exception(
                    line: 1,
                    escape_sequence: "SEQUENCE END",
                    num_escaped_lines: 1,
                    escape_max_lines: 2
                  )
    assert exception.message ==
      "Escape sequence started on line 1 near \"SEQUENCE E\" spanning 1 line did not terminate"
  end

  test "exception messaging about unfinished escape sequences will include options hint if escape sequence hit max lines" do
    exception = EscapeSequenceError.
                  exception(
                    line: 1,
                    escape_sequence: "SEQUENCE END",
                    num_escaped_lines: 2,
                    escape_max_lines: 2
                  )
    assert exception.message ==
      "Escape sequence started on line 1 near \"SEQUENCE E\" spanning 2 lines did not terminate\n\n" <>
      "Maximum number of escaped lines reached\n" <>
      "Escape sequences are allowed to span up to 2 lines. This threshold avoids " <>
      "collecting the whole file into memory when an escape sequence does not terminate. " <>
      "You can change it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2"
  end
end
