defmodule DecodingTests.EscapedFieldsExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.EscapeSequenceError

  test "parses strings unless they contain unfinished escape sequences" do
    stream = ["a,be", "\"c,d"] |> to_stream
    assert_raise EscapeSequenceError, fn ->
      CSV.decode(stream, headers: [:a, :b]) |> Stream.run
    end
  end

  test "raises errors for unfinished escape sequences spanning multiple lines" do
    stream = [",ci,\"\"\"", ",c,d"] |> to_stream

    assert_raise EscapeSequenceError, fn ->
      CSV.decode(stream) |> Stream.run
    end
  end

end
