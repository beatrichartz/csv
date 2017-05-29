defmodule DecodingTests.PreprocessingTests.LinesExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Preprocessing.Lines

  test "passes on open escape sequences at the end of the stream" do
    stream = ["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i", "i,j,\"k", "k,l,m"] |> to_stream
    processed = stream |> Lines.process |> Enum.to_list

    assert processed == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,h,i", "i,j,\"k", "k,l,m"
    ]
  end

  test "passes on if the multiline escape exceeds the maximum number of lines allowed to be aggregated" do
    stream = ["a,\"be\"\"", "c,d", "e,f", "g,h", "i,k", "\",b", "k,l,m"] |> to_stream
    processed = stream |> Lines.process(escape_max_lines: 2) |> Enum.to_list

    assert processed == ["a,\"be\"\"", "c,d", "e,f", "g,h", "i,k", "\",b", "k,l,m"]
  end

  test "passes on open escape sequences with escaped quotes" do
    stream = ["a,\"\"\"be\"\"", "\"\"c,d"] |> to_stream
    processed = stream |> Lines.process |> Enum.to_list

    assert processed == ["a,\"\"\"be\"\"", "\"\"c,d"]
  end

  test "passes on open escape sequences but processes subsequent escape sequences" do
    stream = ["a,\"be\"\"", "c,d", "e,f", "g,\"h", "i,k", "\",b", "k,l,m"] |> to_stream
    processed = stream |> Lines.process(escape_max_lines: 3) |> Enum.to_list

    assert processed == [
      "a,\"be\"\"", "c,d", "e,f",
      "g,\"h\r\ni,k\r\n\",b", "k,l,m"
    ]
  end
end
