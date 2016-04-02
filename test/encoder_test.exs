defmodule EncoderTest do
  use ExUnit.Case
  alias CSV.Encoder, as: Encoder
  doctest Encoder

  test "encodes streams to csv strings" do
    result = Encoder.encode([~w(a b), ~w(c d)]) |> Enum.take(2)
    assert result == ["a,b\r\n", "c,d\r\n"]
  end

  test "allows custom separators and delimiters" do
    result = Encoder.encode([~w(a b), ~w(c d)], separator: ?;, delimiter: "\n") |> Enum.take(2)
    assert result == ["a;b\n", "c;d\n"]
  end

  test "encodes streams to csv strings and escapes them" do
    result = Encoder.encode([["a,", "b\re"], ["c,f\"", "dg"]]) |> Enum.take(2)
    assert result == ["\"a,\",\"b\\re\"\r\n", "\"c,f\"\"\",dg\r\n"]
  end

  test "encodes streams of various content to csv strings and escapes them" do
    result = Encoder.encode([[:atom, 1], [["a", "b"], "dg"]]) |> Enum.take(2)
    assert result == ["atom,1\r\n", "ab,dg\r\n"]
  end

  test "allows custom separators and delimiters and escapes them" do
    result = Encoder.encode([["a\t", "b\re"], ["c\tf\"", "dg"]], separator: ?\t, delimiter: "\n") |> Enum.take(2)
    assert result == ["\"a\\t\"\t\"b\\re\"\n", "\"c\\tf\"\"\"\tdg\n"]
  end

  test "use keys from first row as headers when headers: true" do
    result = Encoder.encode([%{"a" => 1, "b" => 2}], headers: true) |> Enum.to_list()
    assert result == ["a,b\r\n", "1,2\r\n"]
  end

  test "specified headers inserted as first row and used to order columns" do
    result = Encoder.encode([%{"b" => 2}], headers: ["a", "b"]) |> Enum.to_list()
    assert result == ["a,b\r\n", ",2\r\n"]
  end
end
