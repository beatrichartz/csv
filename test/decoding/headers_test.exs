defmodule DecodingTests.HeadersTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoder

  @moduletag timeout: 1000

  test "parses strings into maps when headers are set to true" do
    stream = ["a,be", "c,d", "e,f"] |> to_stream
    result = Decoder.decode!(stream, headers: true) |> Enum.to_list

    assert result |> Enum.sort == [
      %{"a" => "c", "be" => "d"},
      %{"a" => "e", "be" => "f"}
    ]
  end

  test "parses strings and strips cells when headers are given and strip_fields is true" do
    stream = ["h1,h2", "a, be free ", "c,d"] |> to_stream
    result = Decoder.decode!(stream, headers: true, strip_fields: true) |> Enum.to_list

    assert result == [
      %{"h1" => "a", "h2" => "be free"},
      %{"h1" => "c", "h2" => "d"}
    ]
  end

  test "parses strings into maps when headers are given as a list" do
    stream = ["a,be", "c,d"] |> to_stream
    result = Decoder.decode!(stream, headers: [:a, :b]) |> Enum.to_list

    assert result == [
      %{:a => "a", :b => "be"},
      %{:a => "c", :b => "d"}
    ]
  end

end
