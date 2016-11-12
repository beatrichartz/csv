defmodule DecodingTests.EscapedFieldsExceptionsTest do
  use ExUnit.Case
  alias CSV.Decoder
  alias CSV.Parser.SyntaxError
  alias CSV.LineAggregator.CorruptStreamError

  @moduletag timeout: 1000

  defp filter_errors(stream) do
    stream |> Stream.filter(fn
      { :error, _ } -> true
      _ -> false
    end)
  end

  test "parses strings unless they contain unfinished escape sequences" do
    stream = Stream.map(["a,be", "\"c,d"], &(&1))
    assert_raise CorruptStreamError, fn ->
      Decoder.decode!(stream, headers: [:a, :b]) |> Enum.into([])
    end
  end

  test "raises errors for unfinished escape sequences spanning multiple lines" do
    stream = Stream.map([",ci,\"\"\"", ",c,d"], &(&1))

    assert_raise CorruptStreamError, fn ->
      Decoder.decode!(stream) |> Stream.run
    end
  end

  test "raises errors for fields spanning multiple lines if escaping is disabled" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))

    assert_raise SyntaxError, fn ->
      Decoder.decode!(stream, multiline_escape: false) |> Stream.run
    end
  end

  test "emits errors for each row with fields spanning multiple lines if escaping is disabled" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))

    errors = stream |> Decoder.decode(multiline_escape: false) |> filter_errors |> Enum.into([])
    assert errors == [
      error: "Unterminated escape sequence near 'be'",
      error: "Unterminated escape sequence near 'f'"
    ]
  end

end
