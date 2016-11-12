defmodule DecodingTests.BaselineTest do
  use ExUnit.Case
  alias CSV.Decoder

  doctest Decoder

  @moduletag timeout: 1000

  test "parses strings into a list of token tuples and emits them" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses empty lines into a list of token tuples" do
    stream = Stream.map([",", "c,d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [["", ""], ~w(c d)]
  end

  test "parses partially populated lines into a list of token tuples" do
    stream = Stream.map([",ci,\"\"", ",c,d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [["", "ci", ""], ["", "c", "d"]]
  end


  test "parses strings that contain single double quotes" do
    stream = Stream.map(["a,be", "\"c\"\"\",d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [["a", "be"], ["c\"", "d"]]
  end

  test "parses strings that contain multi-byte unicode characters" do
    stream = Stream.map(["a,b", "c,ಠ_ಠ"], &(&1))
    result = CSV.decode!(stream) |> Enum.into([])

    assert result == [["a", "b"], ["c", "ಠ_ಠ"]]
  end

  test "delivers the correct number of rows" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode!(stream) |> Enum.count

    assert result == 6
  end

  test "delivers correctly ordered rows" do
    stream = Stream.map([
      "a,be",
      "c,d",
      "e,f",
      "g,h",
      "i,j",
      "k,l",
      "m,n",
      "o,p",
      "q,r",
      "s,t",
      "u,v",
      "w,x",
      "y,z"
    ], &(&1))
    result = Decoder.decode!(stream, num_pipes: 3) |> Enum.into([])

    assert result ==  [
      ~w(a be),
      ~w(c d),
      ~w(e f),
      ~w(g h),
      ~w(i j),
      ~w(k l),
      ~w(m n),
      ~w(o p),
      ~w(q r),
      ~w(s t),
      ~w(u v),
      ~w(w x),
      ~w(y z),
    ]
  end

end
