defmodule EncodingTests.EscapedFieldsTest do
  use ExUnit.Case
  alias CSV.Encoding.Encoder

  test "encodes streams to csv strings and escapes them" do
    result = Encoder.encode([["a,", "b\re"], ["c,f\"", "dg"]]) |> Enum.to_list
    assert result == ["\"a,\",\"b\\re\"\r\n", "\"c,f\"\"\",dg\r\n"]
  end

  test "encodes streams of various content to csv strings and escapes them" do
    result = Encoder.encode([[:atom, 1], [["a", "b"], "dg"]]) |> Enum.to_list
    assert result == ["atom,1\r\n", "ab,dg\r\n"]
  end

  test "allows custom separators and delimiters and escapes them" do
    result = Encoder.encode([["a\t", "b\re"], ["c\tf\"", "dg"]], separator: ?\t, delimiter: "\n") |> Enum.to_list
    assert result == ["\"a\\t\"\t\"b\\re\"\n", "\"c\\tf\"\"\"\tdg\n"]
  end

  test "force_quotes works with various content" do
    result = Encoder.encode([[:atom, 1], [["a", "b"], "dg"]], force_quotes: true) |> Enum.to_list
    assert result == ["\"atom\",\"1\"\r\n", "\"ab\",\"dg\"\r\n"]
  end

  test "force_quotes works with content that needs escapes" do
    result = Encoder.encode([["a,", "b\re"], ["c,f\"", "dg"]], force_quotes: true) |> Enum.to_list
    assert result == ["\"a,\",\"b\\re\"\r\n", "\"c,f\"\"\",\"dg\"\r\n"]
  end
end
