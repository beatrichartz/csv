defmodule PreprocessingTests.LinesExceptionsTest do
  use ExUnit.Case
  alias CSV.Preprocessors.Lines
  alias CSV.Preprocessors.CorruptStreamError

  test "fails on open escape sequences" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i", "i,j,\"k", "k,l,m"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> Lines.process |> Stream.run
    end
  end

  test "fails if the multiline escape exceeds the maximum number of lines allowed to be aggregated" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f", "g,h", "i,k", "\",b", "k,l,m"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> Lines.process(multiline_escape_max_lines: 2) |> Stream.run
    end
  end

  test "fails on open escape sequences with escaped quotes" do
    stream = Stream.map(["a,\"\"\"be\"\"", "\"\"c,d"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> Lines.process |> Stream.run
    end
  end

end
