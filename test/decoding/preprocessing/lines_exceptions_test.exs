defmodule DecodingTests.PreprocessingTests.LinesExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Preprocessing.Lines
  alias CSV.EscapeSequenceError

  test "fails on open escape sequences" do
    stream = ["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i", "i,j,\"k", "k,l,m"] |> to_stream
    assert_raise EscapeSequenceError,
      "Escape sequence started on line 5 near \"k\r\nk,l,m\" spanning 2 lines did not terminate", fn ->
      stream |> Lines.process |> Stream.run
    end
  end

  test "fails if the multiline escape exceeds the maximum number of lines allowed to be aggregated" do
    stream = ["a,\"be\"\"", "c,d", "e,f", "g,h", "i,k", "\",b", "k,l,m"] |> to_stream
    assert_raise EscapeSequenceError, fn ->
      stream |> Lines.process(escape_max_lines: 2) |> Stream.run
    end
  end

  test "fails on open escape sequences with escaped quotes" do
    stream = ["a,\"\"\"be\"\"", "\"\"c,d"] |> to_stream
    assert_raise EscapeSequenceError, fn ->
      stream |> Lines.process |> Stream.run
    end
  end

end
