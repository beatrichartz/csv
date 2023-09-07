defmodule ExceptionsTest do
  use ExUnit.Case

  alias CSV.EscapeSequenceError
  alias CSV.StrayEscapeCharacterError
  alias CSV.RowLengthError

  test "exception messaging about row length errors" do
    exception =
      RowLengthError.exception(
        row: 3,
        actual_length: 10,
        expected_length: 8
      )

    assert exception.message ==
             "Row 3 has length 10 instead of expected length 8\n\n" <>
               "You are seeing this error because :validate_row_length has been set to true\n"
  end

  test "exception messaging about unfinished escape sequences before stream halt" do
    exception =
      EscapeSequenceError.exception(
        line: 1,
        mode: :normal,
        stream_halted: true,
        escape_sequence_start: "SEQUENCE START",
        escape_max_lines: 2
      )

    assert exception.message ==
             "Escape sequence started on line 1:\n\nSEQUENCE START\n\ndid not terminate " <>
               "before the stream halted. Parsing will continue on line 2.\n"
  end

  test "exception messaging about unfinished escape sequences" do
    exception =
      EscapeSequenceError.exception(
        line: 1,
        mode: :strict,
        escape_sequence_start: "SEQUENCE START",
        escape_max_lines: 2
      )

    assert exception.message ==
             "Escape sequence started on line 1:\n\nSEQUENCE START\n\ndid not terminate. " <>
               "You can use normal mode to continue parsing rows even if single rows have errors.\n\n" <>
               "Escape sequences are allowed to span up to 2 lines. This threshold avoids " <>
               "collecting the whole file into memory when an escape sequence does not terminate.\n" <>
               "You can change it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2\n"
  end

  test "exception messaging about stray escape character errors" do
    exception = StrayEscapeCharacterError.exception(line: 1, sequence: "THIS")

    assert exception.message ==
             "Stray escape character on line 1:\n\nTHIS\n\nThis error often happens when the wrong separator or escape character has been applied.\n"
  end

  test "exception messaging about stray escape character errors can be redacted" do
    exception = StrayEscapeCharacterError.exception(line: 1, sequence: "sensitive", redact: true)

    assert exception.message ==
             "Stray escape character on line 1:\n\n[redacted]\n\nThis error often happens when the wrong separator or escape character has been applied.\n"

    refute exception.message =~ "sensitive"
  end
end
