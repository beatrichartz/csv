defmodule PreprocessingTests.LinesTest do
  use ExUnit.Case
  alias CSV.Preprocessors.Lines

  test "does not aggregate normal lines" do
    stream = Stream.map(["g,h", "i,j", "k,l"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "does not aggregate escaped normal lines" do
    stream = Stream.map(["\"g\",h", "\"i\",j", "k,\"l\""], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "\"g\",h",
      "\"i\",j",
      "k,\"l\""
    ]
  end

  test "does not aggregate escaped normal lines with escaped quotes" do
    stream = Stream.map(["\"g\"\"\",\"\"\"h\"", "\"i\",j", "k,\"\"\"l\""], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "\"g\"\"\",\"\"\"h\"",
      "\"i\",j",
      "k,\"\"\"l\""
    ]
  end

  test "does not aggregate empty lines" do
    stream = Stream.map(["g,", ",", ",l"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "g,",
      ",",
      ",l"
    ]
  end

  test "does not aggregate partially empty lines with escape sequences" do
    stream = Stream.map(["g,", ",\"\"\"\"", ",l", "\"\",\"\""], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "g,",
      ",\"\"\"\"",
      ",l",
      "\"\",\"\""
    ]
  end

  test "does not aggregate terminated escape sequences" do
    stream = Stream.map(["a,\"be\"\"\"", "c,\"\"\"d\"\"\"\"\"", "\"e,f\"\"\",g"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\"",
      "c,\"\"\"d\"\"\"\"\"",
      "\"e,f\"\"\",g"
    ]
  end

  test "aggregates lines with terminated escape sequences and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "\"g\",\"h\"\",\"", "\"i\",\"j\""], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "\"g\",\"h\"\",\"",
      "\"i\",\"j\""
    ]
  end


  test "aggregates unterminated escape sequences over lines" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\r\nc,d\r\ne,f\"",
      "g,h"
    ]
  end

  test "aggregates unterminated escape sequences only containing line breaks over lines" do
    stream = Stream.map(["a,\"", "\"", "c,d"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"\r\n\"",
      "c,d"
    ]
  end

  test "aggregates unterminated escape sequences over rows with different separators" do
    stream = Stream.map(["a\t\"be", "c\td", "e\tf\"", "g\th"], &(&1))
    aggregated = stream |> Lines.process(separator: ?\t) |> Enum.to_list
    assert aggregated == [
      "a\t\"be\r\nc\td\r\ne\tf\"",
      "g\th",
    ]
  end

  test "aggregates unterminated escape sequences over rows with multiple quotes" do
    stream = Stream.map(["a,\"\"\"be", "c,d", "e,f\"", "g,h"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"\"\"be\r\nc,d\r\ne,f\"",
      "g,h"
    ]
  end

  test "aggregates unterminated escape sequences where the sequence begins at the start of the row" do
    stream = Stream.map(["\"\"\"be", "c,d", "e,f\",g", "g,h"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "\"\"\"be\r\nc,d\r\ne,f\",g",
      "g,h"
    ]
  end

  test "aggregates lines with escaped quotes in escape sequences" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\"\"\"", "i,j\"", "k,l"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\"\"\"\r\ni,j\"",
      "k,l"
    ]
  end

  test "aggregates lines with escaped quotes and separators in escapes" do
    stream = Stream.map(["a,\"be\"\"", "c,\"\"d", "e,f\"", "g,\"h\"\",\"\"", "i,j\"", "k,l"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,\"\"d\r\ne,f\"",
      "g,\"h\"\",\"\"\r\ni,j\"",
      "k,l"
    ]
  end

  test "aggregates partially empty lines with open escape sequences" do
    stream = Stream.map([",,\"be", "c,d", "e,f\"", "g,,\"h\"\"\"\"", "i,,j\"", "k,l,"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      ",,\"be\r\nc,d\r\ne,f\"",
      "g,,\"h\"\"\"\"\r\ni,,j\"",
      "k,l,"
    ]
  end


  test "aggregates lines with escape sequences ending in the next line" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,h,i"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,h,i"
    ]
  end

  test "aggregates lines with escape sequences that are ending with a separator" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f,\",\"super,cool\"", "g,h,i"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f,\",\"super,cool\"",
      "g,h,i"
    ]
  end

  test "aggregates lines with escape sequences that are starting with a linebreak" do
    stream = Stream.map(["a,be,\"", "c,d\"", "g,h,i"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,be,\"\r\nc,d\"",
      "g,h,i"
    ]
  end

  test "aggregates lines with escape sequences that are ending with a linebreak" do
    stream = Stream.map(["a,be,\"", "c,\"\"d", "\"\"\"", "g,h,i"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,be,\"\r\nc,\"\"d\r\n\"\"\"",
      "g,h,i"
    ]
  end

  test "aggregates lines with escaped quotes after a linebreak" do
    stream = Stream.map(["a,be,\"", "c", "\"\"d", "e", "\"\"\",f", "g,h,i,k"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,be,\"\r\nc\r\n\"\"d\r\ne\r\n\"\"\",f",
      "g,h,i,k"
    ]
  end

  test "aggregates lines with escape sequences that are containing a linebreak" do
    stream = Stream.map(["a,be,\"\n", "c,\"\"d", "\"\"\"", "g,h,i"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,be,\"\n\r\nc,\"\"d\r\n\"\"\"",
      "g,h,i"
    ]
  end

  test "aggregates lines with multiple escape sequences in the same stream" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\"super,cool\"", "g,\"h,i", "i,j\",k", "k,l,m"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\"super,cool\"",
      "g,\"h,i\r\ni,j\",k",
      "k,l,m"
    ]
  end

  test "aggregates lines with multiple escape sequences in the same row" do
    stream = Stream.map(["a,\"be\"\"", "c,d", "e,f\",\",\",\"super,cool", "g,\"", "h,\"i,l", "\",\"j\",k", "k,l,m"], &(&1))
    aggregated = stream |> Lines.process |> Enum.to_list
    assert aggregated == [
      "a,\"be\"\"\r\nc,d\r\ne,f\",\",\",\"super,cool\r\ng,\"",
      "h,\"i,l\r\n\",\"j\",k",
      "k,l,m"
    ]
  end

end
