defmodule PreprocessingTests.CodepointsTest do
  use ExUnit.Case

  alias CSV.Preprocessors.Codepoints

  test "does collect normal lines" do
    stream = "g,h\ni,j\nk,l\n" |> String.codepoints |> Stream.map(&(&1))
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "does collect lines with escaped fields" do
    stream = "g,h\ni,j\nk,\"l\"\n" |> String.codepoints |> Stream.map(&(&1))
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,\"l\""
    ]
  end

  test "does collect lines with empty fields" do
    stream = "g,h\ni,j\nk,\n" |> String.codepoints |> Stream.map(&(&1))
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,"
    ]
  end

  test "collects lines with escape sequences containing newlines" do
    stream = "g,h\ni,\"j\nk,\"\n" |> String.codepoints |> Stream.map(&(&1))
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,\"j\nk,\"",
    ]
  end

  test "collects lines with escape sequences containing newlines and quotes" do
    stream = "g,h\ni,\"\"\"j\n\"\"k,\"\"\"\n" |> String.codepoints |> Stream.map(&(&1))
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,\"\"\"j\n\"\"k,\"\"\"",
    ]
  end

end
