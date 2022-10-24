defmodule EncodingTests.BaselineTest do
  use ExUnit.Case
  alias CSV.Encoding.Encoder

  doctest Encoder

  test "encodes streams to csv strings" do
    result = Encoder.encode([~w(a b), ~w(c d)]) |> Enum.to_list()
    assert result == ["a,b\r\n", "c,d\r\n"]
  end

  test "allows custom separators and delimiters" do
    result = Encoder.encode([~w(a b), ~w(c d)], separator: ?;, delimiter: "\n") |> Enum.to_list()
    assert result == ["a;b\n", "c;d\n"]
  end

  test "allows forcing of escape characters" do
    result = Encoder.encode([~w(a b), ~w(c d)], force_escaping: true) |> Enum.to_list()
    assert result == ["\"a\",\"b\"\r\n", "\"c\",\"d\"\r\n"]
  end
end
