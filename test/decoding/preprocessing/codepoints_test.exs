defmodule DecodingTests.PreprocessingTests.CodepointsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Preprocessing.Codepoints

  test "does collect lines ending in LF" do
    stream = "g,h\ni,j\nk,l\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "does collect lines ending in CRLF" do
    stream = "g,h\r\ni,j\r\nk,l\r\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "does collect lines ending in CR" do
    stream = "g,h\ri,j\rk,l\r" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

  test "does collect lines with escaped fields" do
    stream = "g,h\ni,j\nk,\"l\"\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,\"l\""
    ]
  end

  test "does collect lines with empty fields" do
    stream = "g,h\ni,j\nk,\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,"
    ]
  end

  test "collects lines with escape sequences containing LF" do
    stream = "g,h\ni,\"j\nk,\"\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,\"j\nk,\"",
    ]
  end

  test "collects lines with escape sequences containing CR" do
    stream = "g,h\ni,\"j\rk,\"\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,\"j\rk,\"",
    ]
  end

  test "collects lines with escape sequences containing CRLF" do
    stream = "g,h\ni,\"j\r\nk,\"\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,\"j\r\nk,\"",
    ]
  end

  test "collects lines with escape sequences containing newlines and quotes" do
    stream = "g,h\ni,\"\"\"j\n\"\"k,\"\"\"\n" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,\"\"\"j\n\"\"k,\"\"\"",
    ]
  end

  test "does collect the last line ending without a newline" do
    stream = "g,h\ni,j\nk,i" |> to_codepoints_stream
    aggregated = stream |> Codepoints.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,i"
    ]
  end

end
