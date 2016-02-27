defmodule LineAggregatorTest do
  use ExUnit.Case
  alias CSV.LineAggregator, as: LineAggregator

  test "the lineaggregator does not aggregate normal rows" do
    stream = Stream.map(["g,h", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "the lineaggregator does not aggregate escaped, terminated rows" do
    stream = Stream.map(["a,\"be\"\"\"", "c,\"\"\"d\"\"\"\"\"", "e,f", "g,h", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\"",
      "c,\"\"\"d\"\"\"\"\"",
      "e,f",
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "the lineaggregator does not aggregate rows with terminated escaped quotes and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\",\"", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\",\"",
      "i,j",
      "k,l"
    ]
  end


  test "the lineaggregator aggregates escaped, unterminated rows" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\r\nc,d\r\ne,f\"",
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "the lineaggregator aggregates escaped, unterminated rows with different separators" do
    stream = Stream.map(["a\t\"be", "c\td", "e\tf\"", "g\th", "i\tj", "k\tl"], &(&1))
    aggregated = stream |> LineAggregator.aggregate(separator: ?\t) |> Enum.into([])
    assert aggregated == [
      "a\t\"be\r\nc\td\r\ne\tf\"",
      "g\th",
      "i\tj",
      "k\tl"
    ]
  end

  test "the lineaggregator aggregates escaped, unterminated rows with multiple quotes" do
    stream = Stream.map(["a,\"\"\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"\"\"be\r\nc,d\r\ne,f\"",
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "the lineaggregator aggregates rows with escaped quotes in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\"\"\"", "i,j\"", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\"\"\"\r\ni,j\"",
      "k,l"
    ]
  end

  test "the lineaggregator aggregates rows with escaped quotes and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\",\"\"", "i,j\"", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\",\"\"\r\ni,j\"",
      "k,l"
    ]
  end

  test "the lineaggregator recognizes open escape sequences which are ending in the middle of the next row and stitches rows together" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i", "i,j,k", "k,l,m"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,h,i",
      "i,j,k",
      "k,l,m"
    ]
  end

end
