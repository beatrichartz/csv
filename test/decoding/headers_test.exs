defmodule DecodingTests.HeadersTest do
  use ExUnit.Case
  alias CSV.Decoder

  @moduletag timeout: 1000

  test "parses strings into maps when headers are set to true" do
    stream = Stream.map(["a,be", "c,d", "e,f"], &(&1))
    result = Decoder.decode!(stream, headers: true) |> Enum.into([])

    assert result |> Enum.sort == [
      %{"a" => "c", "be" => "d"},
      %{"a" => "e", "be" => "f"}
    ]
  end

  test "parses strings and strips cells when headers are given and strip_cells is true" do
    stream = Stream.map(["h1,h2", "a, be free ", "c,d"], &(&1))
    result = Decoder.decode!(stream, headers: true, strip_cells: true) |> Enum.into([])

    assert result == [
      %{"h1" => "a", "h2" => "be free"},
      %{"h1" => "c", "h2" => "d"}
    ]
  end

  test "parses strings into maps when headers are given as a list" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = Decoder.decode!(stream, headers: [:a, :b]) |> Enum.into([])

    assert result == [
      %{:a => "a", :b => "be"},
      %{:a => "c", :b => "d"}
    ]
  end

end
