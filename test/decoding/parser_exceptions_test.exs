defmodule DecodingTests.ParserExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Parser
  alias CSV.EscapeSequenceError
  alias CSV.StrayQuoteError

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
             {:error, StrayQuoteError, [line: 1, sequence_position: 2, sequence: "a\",\"be\n"]},
             {:error, StrayQuoteError,
              [line: 3, sequence_position: 6, sequence: "\"c,d\n\"e,f\"g\",h"]},
             {:error, StrayQuoteError, [line: 3, sequence_position: 5, sequence: "\"e,f\"g\",h"]},
             {:ok, ["j", "k"]}
           ]
  end

  test "includes an error for rows with unescaped quotes in escape sequences on the same line" do
    stream = ["a,\"b\"e", "\"c,\"d", "\"e,f\"g\",h", "j,k"] |> to_line_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayQuoteError, [line: 1, sequence_position: 3, sequence: "\"b\"e"]},
             {:error, StrayQuoteError, [line: 2, sequence_position: 4, sequence: "\"c,\"d"]},
             {:error, StrayQuoteError, [line: 3, sequence_position: 5, sequence: "\"e,f\"g\",h"]},
             {:ok, ["j", "k"]}
           ]
  end

  test "includes an error with a the correct sequence for byte chunk parsed rows with unescaped quotes" do
    stream = ["a\",\"be\n", "\"c,", ",d\n", "\"e,f\"", "g\",h\n", "j,k"] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayQuoteError, [line: 1, sequence_position: 2, sequence: "a\",\"be\n"]},
             {:error, StrayQuoteError,
              [line: 3, sequence_position: 7, sequence: "\"c,,d\n\"e,f\""]},
             {:error, StrayQuoteError, [line: 3, sequence_position: 5, sequence: "\"e,f\"g\",h"]},
             {:ok, ["j", "k"]}
           ]
  end

  test "includes an error for rows with unescaped quotes at the end of the stream" do
    stream = ["a\",\"be\n", "e,fg,hh\""] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayQuoteError, [line: 1, sequence_position: 2, sequence: "a\",\"be\n"]},
             {:error, StrayQuoteError, [line: 2, sequence_position: 8, sequence: "e,fg,hh\""]}
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

  test "includes an error for escape sequences that do not terminate before the end of the file and parses following lines" do
    stream = ["a,\"be", "c,d", "e,f", "g,h"] |> to_line_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, EscapeSequenceError,
              [
                line: 1,
                stream_halted: true,
                escape_sequence_start: "\"be"
              ]},
             {:ok, ["c", "d"]},
             {:ok, ["e", "f"]},
             {:ok, ["g", "h"]}
           ]
  end

  test "includes an error for escape sequences that do not terminate before the end of the file and parses following lines with no newline at the end" do
    stream = ["a,\"be\n", "c,d\n", "e,f\n", "g,"] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, EscapeSequenceError,
              [
                line: 1,
                stream_halted: true,
                escape_sequence_start: "\"be"
              ]},
             {:ok, ["c", "d"]},
             {:ok, ["e", "f"]},
             {:ok, ["g", ""]}
           ]
  end

  test "includes an error for repeated escape sequences that do not terminate before the end of the file and parses following lines with no newline at the end" do
    stream = ["a,\"be\n", "c,\"d\"\n", "e,\"f\n", "g,"] |> to_stream
    errors = stream |> Parser.parse() |> Enum.to_list()

    assert errors == [
             {:error, StrayQuoteError,
              [
                line: 2,
                sequence_position: 7,
                sequence: "\"be\nc,\"d\""
              ]},
             {:ok, ["c", "d"]},
             {:error, EscapeSequenceError,
              [
                line: 3,
                stream_halted: true,
                escape_sequence_start: "\"f"
              ]},
             {:ok, ["g", ""]}
           ]
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
