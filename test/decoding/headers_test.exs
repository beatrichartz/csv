defmodule DecodingTests.HeadersTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder

  test "parses strings into maps when headers are set to true" do
    stream = ["a,be", "c,d", "e,f"] |> to_line_stream
    result = Decoder.decode(stream, headers: true) |> Enum.to_list()

    assert result |> Enum.sort() == [
             ok: %{"a" => "c", "be" => "d"},
             ok: %{"a" => "e", "be" => "f"}
           ]
  end

  test "parses strings and applies a configured field finalizer" do
    stream = ["h1,h2", "a, be free ", "c,d"] |> to_line_stream

    result =
      Decoder.decode(stream, headers: true, field_transform: &String.trim/1) |> Enum.to_list()

    assert result == [
             ok: %{"h1" => "a", "h2" => "be free"},
             ok: %{"h1" => "c", "h2" => "d"}
           ]
  end

  test "parses strings into maps when headers are given as a list" do
    stream = ["a,be", "c,d"] |> to_line_stream
    result = Decoder.decode(stream, headers: [:a, :b]) |> Enum.to_list()

    assert result == [
             ok: %{:a => "a", :b => "be"},
             ok: %{:a => "c", :b => "d"}
           ]
  end

  test "parses strings into maps when there are duplicate headers" do
    stream =
      [
        "a,b,c,c,d,d,d",
        "a1,b1,c1,c2,d1,d2,d3"
      ]
      |> to_line_stream

    result = Decoder.decode(stream, headers: true) |> Enum.to_list()

    assert result |> Enum.sort() == [
             ok: %{"a" => "a1", "b" => "b1", "c" => ["c1", "c2"], "d" => ["d1", "d2", "d3"]}
           ]
  end
end
