defmodule DecodingTests.EscapedFieldsExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  test "parses strings unless they contain unfinished escape sequences" do
    stream = ["a,be", "\"c,d", "u,z"] |> to_line_stream
    result = CSV.decode(stream, headers: [:a, :b]) |> Enum.to_list()

    assert result == [
             ok: %{a: "a", b: "be"},
             error:
               "Escape sequence started on line 2:\n\n\"c,d\n\ndid not terminate " <>
                 "before the stream halted. Parsing will continue on line 3.\n",
             ok: %{a: "u", b: "z"}
           ]
  end

  test "raises errors for unfinished escape sequences spanning multiple lines" do
    stream = [",ci,\"\"\"", ",c,d"] |> to_line_stream
    result = stream |> CSV.decode() |> Enum.to_list()

    assert result == [
             error:
               "Escape sequence started on line 1:\n\n\"\"\"\n\ndid not terminate " <>
                 "before the stream halted. Parsing will continue on line 2.\n",
             ok: ["", "c", "d"]
           ]
  end

  test "raises errors for unfinished escape sequences spanning multiple lines and custom escape characters" do
    stream = [",ci,@@@", ",c,d"] |> to_line_stream
    result = stream |> CSV.decode(escape_character: ?@) |> Enum.to_list()

    assert result == [
             error:
               "Escape sequence started on line 1:\n\n@@@\n\ndid not terminate " <>
                 "before the stream halted. Parsing will continue on line 2.\n",
             ok: ["", "c", "d"]
           ]
  end

  test "raises errors for unfinished escape sequences in strict mode" do
    stream = [",ci,\"\"\"", ",c,d"] |> to_line_stream

    assert_raise CSV.EscapeSequenceError, fn ->
      CSV.decode!(stream) |> Stream.run()
    end
  end

  test "raises errors for stray quotes in strict mode" do
    stream = [",ci\",", ",c,d"] |> to_line_stream

    assert_raise CSV.StrayEscapeCharacterError, fn ->
      CSV.decode!(stream) |> Stream.run()
    end
  end
end
