defmodule DecodingTests.PreprocessingTests.CodepointsExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Preprocessing.Codepoints
  alias CSV.CorruptStreamError

  test "fails on open escape sequences with escaped quotes" do
    stream = "a,\"\"\"be\"\"\"\"c,d" |> to_codepoints_stream
    assert_raise CorruptStreamError, fn ->
      stream |> Codepoints.process |> Stream.run
    end
  end

  test "fails if the multiline escape exceeds the maximum number of lines allowed to be collected" do
    stream = "a,\"be\"\"c\n,de\n,f\ng,hi,k\",bk,l,m" |> to_codepoints_stream
    assert_raise CorruptStreamError, fn ->
      stream |> Codepoints.process(escape_max_lines: 2) |> Stream.run
    end
  end

end
