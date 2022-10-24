defmodule DecodingTests.ParserExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Parser
  alias CSV.EscapeSequenceError
  alias CSV.StrayEscapeCharacterError

  test "parses encodings as-is without validation" do
    stream = "../fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!()

    result =
      stream
      |> Parser.parse()
      |> Enum.to_list()

    assert result == [{:ok, ["a", "b", "c", <<191, 95, 191>>]}, {:ok, ["ಠ_ಠ"]}]
  end

  test "empty stream input produces an empty stream as output" do
    stream = [] |> to_line_stream
    assert stream |> Parser.parse() |> Enum.to_list() == []
  end

  test "can reuse the same stream" do
    stream =
      ["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"]
      |> to_line_stream
      |> Parser.parse()

    result = stream |> Enum.take(2)

    assert result == [ok: ~w(a be), ok: ~w(c d)]

    next_result = stream |> Enum.take(2)
    assert next_result == [ok: ~w(a be), ok: ~w(c d)]
  end

  test "includes an error for rows with unescaped quotes" do
    stream = ["a\",\"be", "\"c,d", "\"e,f\"g\",h", "j,k"] |> to_line_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayEscapeCharacterError, [line: 1, sequence: "a\",\"be"]},
             {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"c,d\n\"e,f\"g\",h"]},
             {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"e,f\"g\",h"]},
             {:ok, ["j", "k"]}
           ]
  end

  test "includes an error for rows with unescaped quotes in a byte stream" do
    1..5
    |> Enum.each(fn size ->
      stream = "a\",\"be\n\"c,d\n\"e,f\"g\",h\nj,k\nm,l\no,p" |> to_byte_stream(size)
      errors = stream |> Parser.parse() |> Enum.to_list()

      assert errors == [
               {:error, StrayEscapeCharacterError, [line: 1, sequence: "a\",\"be"]},
               {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"c,d\n\"e,f\"g\",h"]},
               {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"e,f\"g\",h"]},
               {:ok, ["j", "k"]},
               {:ok, ["m", "l"]},
               {:ok, ["o", "p"]}
             ]
    end)
  end

  test "includes an error for rows with unescaped quotes in escape sequences on the same line" do
    stream = ["a,\"b\"e", "\"c,\"d", "\"e,f\"g\",h", "j,k"] |> to_line_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayEscapeCharacterError, [line: 1, sequence: "\"b\"e"]},
             {:error, StrayEscapeCharacterError, [line: 2, sequence: "\"c,\"d"]},
             {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"e,f\"g\",h"]},
             {:ok, ["j", "k"]}
           ]
  end

  test "includes an error for rows with unescaped quotes in escape sequences on the same line in a byte stream" do
    1..10
    |> Enum.each(fn size ->
      stream = "a,\"b\"e\n\"c,\"d\n\"e,f\"g\",h\nj,k" |> to_byte_stream(size)
      errors = stream |> Parser.parse() |> Enum.to_list()

      assert errors == [
               {:error, StrayEscapeCharacterError, [line: 1, sequence: "\"b\"e"]},
               {:error, StrayEscapeCharacterError, [line: 2, sequence: "\"c,\"d"]},
               {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"e,f\"g\",h"]},
               {:ok, ["j", "k"]}
             ]
    end)
  end

  test "includes an error with a the correct sequence for byte chunk parsed rows with unescaped quotes" do
    stream = ["a\",\"be\n", "\"c,", ",d\n", "\"e,f\"", "g\",h\n", "j,k"] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayEscapeCharacterError, [line: 1, sequence: "a\",\"be"]},
             {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"c,,d\n\"e,f\"g\",h"]},
             {:error, StrayEscapeCharacterError, [line: 3, sequence: "\"e,f\"g\",h"]},
             {:ok, ["j", "k"]}
           ]
  end

  test "includes an error for rows with unescaped quotes at the end of the stream" do
    stream = ["a\",\"be\n", "e,fg,hh\""] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayEscapeCharacterError, [line: 1, sequence: "a\",\"be"]},
             {:error, StrayEscapeCharacterError,
              [line: 2, sequence: "e,fg,hh\"", stream_halted: true]}
           ]
  end

  test "includes an error for rows with unescaped quotes at the end of the stream for a byte stream" do
    10..25
    |> Enum.each(fn size ->
      stream = "a\",\"be\ne,fg,hh\"" |> to_byte_stream(size)
      errors = stream |> Parser.parse() |> Enum.to_list()

      assert errors == [
               {:error, StrayEscapeCharacterError, [line: 1, sequence: "a\",\"be"]},
               {:error, StrayEscapeCharacterError,
                [line: 2, sequence: "e,fg,hh\"", stream_halted: true]}
             ]
    end)
  end

  test "includes escape sequences with a stray escape character on the last line" do
    stream = "a,\"b,c\nd,e\n,f\"\" \"a" |> to_byte_stream(10)
    result = Parser.parse(stream) |> Enum.to_list()

    assert result == [
             {:error, StrayEscapeCharacterError,
              [line: 3, sequence: "b,c\nd,e\n,f\"\" \"a", stream_halted: true]}
           ]
  end

  test "includes an error for escape sequences that do not terminate within a number of lines and parses following lines" do
    stream = ["a,\"be", "c,d", "e,f", "g,h"] |> to_line_stream
    errors = stream |> Parser.parse(escape_max_lines: 2) |> Enum.to_list()

    assert errors == [
             {:error, EscapeSequenceError,
              [
                line: 1,
                escape_max_lines: 2,
                escape_sequence_start: "\"be"
              ]},
             {:ok, ["c", "d"]},
             {:ok, ["e", "f"]},
             {:ok, ["g", "h"]}
           ]
  end

  test "includes an error for escape sequences that do not terminate within a number of lines and parses following lines for a byte stream" do
    1..25
    |> Enum.each(fn size ->
      stream = "a,\"be\nc,d\ne,f\ng,h\n" |> to_byte_stream(size)
      errors = stream |> Parser.parse(escape_max_lines: 2) |> Enum.to_list()

      assert errors == [
               {:error, EscapeSequenceError,
                [
                  line: 1,
                  escape_max_lines: 2,
                  escape_sequence_start: "\"be"
                ]},
               {:ok, ["c", "d"]},
               {:ok, ["e", "f"]},
               {:ok, ["g", "h"]}
             ]
    end)
  end

  test "includes an error for escape sequences that do not terminate before the end of the file and parses following lines" do
    stream = ["a,\"be", "c,d", "e,f", "g,h"] |> to_line_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, EscapeSequenceError,
              [
                line: 1,
                escape_max_lines: 4,
                escape_sequence_start: "\"be",
                stream_halted: true
              ]},
             {:ok, ["c", "d"]},
             {:ok, ["e", "f"]},
             {:ok, ["g", "h"]}
           ]
  end

  test "includes an error for escape sequences that do not terminate before the end of the file and parses following lines for a byte stream" do
    1..15
    |> Enum.each(fn size ->
      stream = "a,\"be\nc,d\ne,f\ng,h\n" |> to_byte_stream(size)
      errors = stream |> Parser.parse() |> Enum.to_list()

      assert errors == [
               {:error, EscapeSequenceError,
                [
                  line: 1,
                  escape_max_lines: 4,
                  escape_sequence_start: "\"be",
                  stream_halted: true
                ]},
               {:ok, ["c", "d"]},
               {:ok, ["e", "f"]},
               {:ok, ["g", "h"]}
             ]
    end)
  end

  test "includes an error for escape sequences that do not terminate before the end of the file and parses following lines with no newline at the end" do
    stream = ["a,\"be\n", "c,d\n", "e,f\n", "g,"] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, EscapeSequenceError,
              [
                line: 1,
                escape_max_lines: 3,
                escape_sequence_start: "\"be",
                stream_halted: true
              ]},
             {:ok, ["c", "d"]},
             {:ok, ["e", "f"]},
             {:ok, ["g", ""]}
           ]
  end

  test "includes an error for escape sequences that do not terminate before the end of the file and parses following lines with no newline at the end for a byte stream" do
    1..25
    |> Enum.each(fn size ->
      stream = "a,\"be\nc,d\ne,f\ng," |> to_byte_stream(size)
      errors = stream |> Parser.parse() |> Enum.to_list()

      assert errors == [
               {:error, EscapeSequenceError,
                [
                  line: 1,
                  escape_max_lines: 3,
                  escape_sequence_start: "\"be",
                  stream_halted: true
                ]},
               {:ok, ["c", "d"]},
               {:ok, ["e", "f"]},
               {:ok, ["g", ""]}
             ]
    end)
  end

  test "includes an error for repeated escape sequences that do not terminate before the end of the file and parses following lines with no newline at the end" do
    stream = ["a,\"be\n", "c,\"d\"\n", "e,\"f\n", "g,"] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayEscapeCharacterError,
              [
                line: 2,
                sequence: "\"be\nc,\"d\""
              ]},
             {:ok, ["c", "d"]},
             {:error, EscapeSequenceError,
              [
                line: 3,
                escape_max_lines: 1,
                escape_sequence_start: "\"f",
                stream_halted: true
              ]},
             {:ok, ["g", ""]}
           ]
  end

  test "includes an error for repeated escape sequences that do not terminate before the end of the file and parses following lines with no newline at the end for a byte stream" do
    1..25
    |> Enum.each(fn size ->
      stream = "a,\"be\nc,\"d\"\ne,\"f\ng," |> to_byte_stream(size)
      errors = stream |> Parser.parse() |> Enum.to_list()

      assert errors == [
               {:error, StrayEscapeCharacterError,
                [
                  line: 2,
                  sequence: "\"be\nc,\"d\""
                ]},
               {:ok, ["c", "d"]},
               {:error, EscapeSequenceError,
                [
                  line: 3,
                  escape_max_lines: 1,
                  escape_sequence_start: "\"f",
                  stream_halted: true
                ]},
               {:ok, ["g", ""]}
             ]
    end)
  end

  def encode_decode_loop(l, opts \\ []) do
    l |> CSV.encode(opts) |> Parser.parse(opts) |> Enum.to_list()
  end

  test "does not get corrupted after an error" do
    assert_raise Protocol.UndefinedError, fn ->
      ~w(a) |> encode_decode_loop
    end

    result_a = [~w(b)] |> encode_decode_loop
    result_b = [~w(b)] |> encode_decode_loop
    result_c = [~w(b)] |> encode_decode_loop

    assert result_a == [ok: ~w(b)]
    assert result_b == [ok: ~w(b)]
    assert result_c == [ok: ~w(b)]
  end
end
