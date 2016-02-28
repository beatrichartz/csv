defmodule LineAggregatorTest do
  use ExUnit.Case
  alias CSV.LineAggregator
  alias CSV.LineAggregator.CorruptStreamError

  test "does not aggregate normal rows" do
    stream = Stream.map(["g,h", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "does not aggregate empty rows" do
    stream = Stream.map(["g,", ",", ",l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "g,",
      ",",
      ",l"
    ]
  end

  test "does not aggregate empty rows with escapes" do
    stream = Stream.map(["g,", ",\"\"", ",l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "g,",
      ",\"\"",
      ",l"
    ]
  end

  test "does not aggregate escaped, terminated rows" do
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

  test "does not aggregate rows with terminated escaped quotes and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\",\"", "i,j", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\",\"",
      "i,j",
      "k,l"
    ]
  end


  test "aggregates escaped, unterminated rows" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\r\nc,d\r\ne,f\"",
      "g,h"
    ]
  end

  test "aggregates escaped, unterminated rows only containing a linebreak" do
    stream = Stream.map(["a,\"", "\"", "c,d"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"\r\n\"",
      "c,d"
    ]
  end

  test "aggregates escaped, unterminated rows with different separators" do
    stream = Stream.map(["a\t\"be", "c\td", "e\tf\"", "g\th"], &(&1))
    aggregated = stream |> LineAggregator.aggregate(separator: ?\t) |> Enum.into([])
    assert aggregated == [
      "a\t\"be\r\nc\td\r\ne\tf\"",
      "g\th",
    ]
  end

  test "aggregates escaped, unterminated rows with multiple quotes" do
    stream = Stream.map(["a,\"\"\"be", "c,d", "e,f\"", "g,h"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"\"\"be\r\nc,d\r\ne,f\"",
      "g,h"
    ]
  end

  test "aggregates escaped, unterminated where the escape begins at the start" do
    stream = Stream.map(["\"\"\"be", "c,d", "e,f\",g", "g,h"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "\"\"\"be\r\nc,d\r\ne,f\",g",
      "g,h"
    ]
  end

  test "aggregates rows with escaped quotes in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\"\"\"", "i,j\"", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\"\"\"\r\ni,j\"",
      "k,l"
    ]
  end

  test "aggregates rows with escaped quotes and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\",\"\"", "i,j\"", "k,l"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\",\"\"\r\ni,j\"",
      "k,l"
    ]
  end

  test "aggregates partially empty rows with open escape sequences" do
    stream = Stream.map([",,\"be", "c,d", "e,f\"", "g,,\"h\"\"\"\"", "i,,j\"", "k,l,"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      ",,\"be\r\nc,d\r\ne,f\"",
      "g,,\"h\"\"\"\"\r\ni,,j\"",
      "k,l,"
    ]
  end


  test "recognizes open escape sequences which are ending in the middle of the next row and stitches rows together" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,h,i"
    ]
  end

  test "recognizes open escape sequences which are ending after a separator and stitches rows together" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f,\",\"super,cool\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f,\",\"super,cool\"",
      "g,h,i"
    ]
  end

  test "recognizes open escape sequences with a line break right after the quote and stitches rows together" do
    stream = Stream.map(["a,be,\"", "c,d\"", "g,h,i", "i,j,k", "k,l,m"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,be,\"\r\nc,d\"",
      "g,h,i",
      "i,j,k",
      "k,l,m"
    ]
  end

  test "recognizes multiple open escape sequences in a stream" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,\"h,i", "i,j\",k", "k,l,m"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,\"h,i\r\ni,j\",k",
      "k,l,m"
    ]
  end

  test "recognizes multiple open escape sequences in a row" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool", "g,\"", "h,\"i,l", "\",j", "k,l,m"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\r\ng,\"",
      "h,\"i,l\r\n\",j",
      "k,l,m"
    ]
  end

  test "fails on open escape sequences at the end of the stream" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i", "i,j,\"k", "k,l,m"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> LineAggregator.aggregate |> Stream.run
    end
  end

end
