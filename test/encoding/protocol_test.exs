defmodule EncodingTests.ProtocolTest do
  use ExUnit.Case
  alias CSV.Encode

  test "it defines standard encoding for strings" do
    assert Encode.encode(",this") == "\",this\""
  end

  test "it correctly escapes double quotes" do
    assert Encode.encode("a\"b") == "\"a\"\"b\""
  end

  test "it falls back to to_string for integers" do
    assert Encode.encode(1) == "1"
  end

  test "it falls back to to_string for atoms" do
    assert Encode.encode(:atom) == "atom"
  end

  test "it falls back to to_string for lists" do
    assert Encode.encode([1, 2, 3]) == <<1, 2, 3>>
  end
end
