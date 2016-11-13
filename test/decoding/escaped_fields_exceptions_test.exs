defmodule DecodingTests.EscapedFieldsExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoder
  alias CSV.Preprocessors.CorruptStreamError

  @moduletag timeout: 1000

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

end
