defmodule EncodingTests.HeadersTest do
  use ExUnit.Case
  alias CSV.Encoding.Encoder

  test "use keys from first row as headers when headers: true" do
    result = Encoder.encode([%{"a" => 1, "b" => 2}], headers: true) |> Enum.to_list()
    assert result == ["a,b\r\n", "1,2\r\n"]
  end

  test "inserts specified headers as first row and uses them to order columns" do
    result = Encoder.encode([%{"c" => 1, "b" => 2}], headers: ["c", "b", "a"]) |> Enum.to_list()
    assert result == ["c,b,a\r\n", "1,2,\r\n"]
  end

  test "inserts value of keyword list from header param" do
    result =
      Encoder.encode([%{a: 1, b: 2, c: 3}], headers: [a: "c", b: "b", c: "a"]) |> Enum.to_list()

    assert result == ["c,b,a\r\n", "1,2,3\r\n"]
  end

  test "inserts value of keyword list from header param with extra columns" do
    result =
      Encoder.encode([%{a: 1, b: 2, c: 3}], headers: [a: "c", b: "b", c: "a", d: "x"])
      |> Enum.to_list()

    assert result == ["c,b,a,x\r\n", "1,2,3,\r\n"]
  end

  test "inserts value of keyword list from header param with reordered columns" do
    result =
      Encoder.encode([%{c: 3, b: 2, a: 1}], headers: [a: "c", b: "b", c: "a", d: "x"])
      |> Enum.to_list()

    assert result == ["c,b,a,x\r\n", "1,2,3,\r\n"]
  end
end
