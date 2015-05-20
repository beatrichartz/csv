defmodule EncodeTest do
  use ExUnit.Case

  defmodule Data do
    defstruct a: "AA", b: 27
  end

  defimpl CSV.Encode, for: Data do
    def encode(%Data{a: a, b: b}, _env \\ []) do
      "#{a} or #{b}"
    end
  end

  setup do
    data = %Data{}
    {:ok, data: data}
  end

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

  test "it allows to define the encoding for something", context do
    assert CSV.Encode.encode(context[:data]) == "AA or 27"
  end

end
