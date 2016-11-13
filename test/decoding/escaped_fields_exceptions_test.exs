defmodule DecodingTests.EscapedFieldsExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoder
  alias CSV.Parser.SyntaxError
  alias CSV.Preprocessors.CorruptStreamError

  @moduletag timeout: 1000

  defp filter_errors(stream) do
    stream |> Stream.filter(fn
      { :error, _ } -> true
      _ -> false
    end)
  end

  test "parses strings unless they contain unfinished escape sequences" do
    stream = ["a,be", "\"c,d"] |> to_stream
    assert_raise CorruptStreamError, fn ->
      Decoder.decode!(stream, headers: [:a, :b]) |> Enum.to_list
    end
  end

  test "raises errors for unfinished escape sequences spanning multiple lines" do
    stream = [",ci,\"\"\"", ",c,d"] |> to_stream

    assert_raise CorruptStreamError, fn ->
      Decoder.decode!(stream) |> Stream.run
    end
  end

  test "raises errors for fields spanning multiple lines if escaping is disabled" do
    stream = ["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"] |> to_stream

    assert_raise SyntaxError, fn ->
      Decoder.decode!(stream, multiline_escape: false) |> Stream.run
    end
  end

  test "emits errors for each row with fields spanning multiple lines if escaping is disabled" do
    stream = ["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"] |> to_stream

    errors = stream |> Decoder.decode(multiline_escape: false) |> filter_errors |> Enum.to_list
    assert errors == [
      error: "Unterminated escape sequence near 'be'",
      error: "Unterminated escape sequence near 'f'"
    ]
  end

end
