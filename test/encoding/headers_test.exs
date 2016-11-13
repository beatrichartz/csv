defmodule EncodingTests.HeadersTest do
  use ExUnit.Case
  alias CSV.Encoding.Encoder

  test "use keys from first row as headers when headers: true" do
    result = Encoder.encode([%{"a" => 1, "b" => 2}], headers: true) |> Enum.to_list
    assert result == ["a,b\r\n", "1,2\r\n"]
  end

  test "inserts specified headers as first row and uses them to order columns" do
    result = Encoder.encode([%{"b" => 2}], headers: ["a", "b"]) |> Enum.to_list
    assert result == ["a,b\r\n", ",2\r\n"]
  end
end
