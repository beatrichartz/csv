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

  test "does not aggregate escaped normal rows" do
    stream = Stream.map(["\"g\",h", "\"i\",j", "k,\"l\""], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "\"g\",h",
      "\"i\",j",
      "k,\"l\""
    ]
  end

  test "does not aggregate escaped normal rows with escaped quotes" do
    stream = Stream.map(["\"g\"\"\",\"\"\"h\"", "\"i\",j", "k,\"\"\"l\""], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "\"g\"\"\",\"\"\"h\"",
      "\"i\",j",
      "k,\"\"\"l\""
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

  test "does not aggregate partially empty rows with escape sequences" do
    stream = Stream.map(["g,", ",\"\"\"\"", ",l", "\"\",\"\""], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "g,",
      ",\"\"\"\"",
      ",l",
      "\"\",\"\""
    ]
  end

  test "does not aggregate terminated escape sequences" do
    stream = Stream.map(["a,\"be\"\"\"", "c,\"\"\"d\"\"\"\"\"", "\"e,f\"\"\",g"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\"",
      "c,\"\"\"d\"\"\"\"\"",
      "\"e,f\"\"\",g"
    ]
  end

  test "aggregates rows with terminated escape sequences and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "\"g\",\"h\"\",\"", "\"i\",\"j\""], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "\"g\",\"h\"\",\"",
      "\"i\",\"j\""
    ]
  end


  test "aggregates unterminated escape sequences over rows" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\r\nc,d\r\ne,f\"",
      "g,h"
    ]
  end

  test "aggregates unterminated escape sequences only containing line breaks over rows" do
    stream = Stream.map(["a,\"", "\"", "c,d"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"\r\n\"",
      "c,d"
    ]
  end

  test "aggregates unterminated escape sequences over rows with different separators" do
    stream = Stream.map(["a\t\"be", "c\td", "e\tf\"", "g\th"], &(&1))
    aggregated = stream |> LineAggregator.aggregate(separator: ?\t) |> Enum.into([])
    assert aggregated == [
      "a\t\"be\r\nc\td\r\ne\tf\"",
      "g\th",
    ]
  end

  test "aggregates unterminated escape sequences over rows with multiple quotes" do
    stream = Stream.map(["a,\"\"\"be", "c,d", "e,f\"", "g,h"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"\"\"be\r\nc,d\r\ne,f\"",
      "g,h"
    ]
  end

  test "aggregates unterminated escape sequences where the sequence begins at the start of the row" do
    stream = Stream.map(["\"\"\"be", "c,d", "e,f\",g", "g,h"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "\"\"\"be\r\nc,d\r\ne,f\",g",
      "g,h"
    ]
  end

  test "aggregates rows with escaped quotes in escape sequences" do
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


  test "aggregates rows with escape sequences ending in the next row" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,h,i"
    ]
  end

  test "aggregates rows with escape sequences that are ending with a separator" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f,\",\"super,cool\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f,\",\"super,cool\"",
      "g,h,i"
    ]
  end

  test "aggregates rows with escape sequences that are starting with a linebreak" do
    stream = Stream.map(["a,be,\"", "c,d\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,be,\"\r\nc,d\"",
      "g,h,i"
    ]
  end

  test "aggregates rows with escape sequences that are ending with a linebreak" do
    stream = Stream.map(["a,be,\"", "c,\"\"\"d", "\"\"\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,be,\"\r\nc,\"\"\"d\r\n\"\"\"",
      "g,h,i"
    ]
  end

  test "aggregates rows with escape sequences that are containing a linebreak" do
    stream = Stream.map(["a,be,\"\n", "c,\"\"\"d", "\"\"\"", "g,h,i"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,be,\"\n\r\nc,\"\"\"d\r\n\"\"\"",
      "g,h,i"
    ]
  end

  test "aggregates rows with multiple escape sequences in the same stream" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,\"h,i", "i,j\",k", "k,l,m"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,\"h,i\r\ni,j\",k",
      "k,l,m"
    ]
  end

  test "aggregates rows with multiple escape sequences in the same row" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\",\",\"super,cool", "g,\"", "h,\"i,l", "\",\"j\",k", "k,l,m"], &(&1))
    aggregated = stream |> LineAggregator.aggregate |> Enum.into([])
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\",\",\"super,cool\r\ng,\"",
      "h,\"i,l\r\n\",\"j\",k",
      "k,l,m"
    ]
  end

  test "fails on open escape sequences" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i", "i,j,\"k", "k,l,m"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> LineAggregator.aggregate |> Stream.run
    end
  end

  test "fails if the multiline escape exceeds the maximum number of lines allowed to be aggregated" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f", "g,h", "i,k", "\",b", "k,l,m"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> LineAggregator.aggregate(multiline_escape_max_lines: 2) |> Stream.run
    end
  end

  test "fails on open escape sequences with escaped quotes" do
    stream = Stream.map(["a,\"\"\"be\"\"", "\"\"c,d"], &(&1))
    assert_raise CorruptStreamError, fn ->
      stream |> LineAggregator.aggregate |> Stream.run
    end
  end

end
