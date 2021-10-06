defmodule EncodingTests.EscapedFieldsTest do
  use ExUnit.Case
  alias CSV.Encoding.Encoder

  test "encodes streams to csv strings and escapes them" do
    result = Encoder.encode([["a,", "b\re"], ["c,f\"", "dg"]]) |> Enum.to_list()
    assert result == ["\"a,\",\"b\re\"\r\n", "\"c,f\"\"\",dg\r\n"]
  end

  test "encodes formulas and escapes them" do
    result =
      Encoder.encode(
        [["=1+1", ~S(=1+2";=1+2), ~S(=1+2'" ;,=1+2)], ["-10+7"], ["+10+7"], ["@A1:A10"]],
        escape_formulas: true
      )
      |> Enum.to_list()

    assert result == [
             ~S("'=1+1","'=1+2"";=1+2","'=1+2'"" ;,=1+2") <> "\r\n",
             ~S("'-10+7") <> "\r\n",
             ~S("'+10+7") <> "\r\n",
             ~S("'@A1:A10") <> "\r\n"
           ]
  end

  test "encodes streams of various content to csv strings and escapes them" do
    result = Encoder.encode([[:atom, 1], [["a", "b"], "dg"]]) |> Enum.to_list()
    assert result == ["atom,1\r\n", "ab,dg\r\n"]
  end

  test "allows custom separators and delimiters and escapes them" do
    result =
      Encoder.encode([["a\t", "b\re"], ["c\tf\"", "dg"]], separator: ?\t, delimiter: "\n")
      |> Enum.to_list()

    assert result == ["\"a\t\"\t\"b\re\"\n", "\"c\tf\"\"\"\tdg\n"]
  end
end
