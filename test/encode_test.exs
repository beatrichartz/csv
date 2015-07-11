defmodule EncodeTest do
  use ExUnit.Case

  test "it defines standard encoding for strings" do
    assert CSV.Encode.encode(",this") == "\",this\""
  end

  test "it falls back to to_string for integers" do
    assert CSV.Encode.encode(1) == "1"
  end

  test "it falls back to to_string for atoms" do
    assert CSV.Encode.encode(:atom) == "atom"
  end

  test "it falls back to to_string for lists" do
    assert CSV.Encode.encode([1,2,3]) == <<1, 2, 3>>
  end

end
