defmodule DecodingTests.BaselineTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoder

  doctest Decoder

  @moduletag timeout: 1000

  test "parses strings into a list of token tuples and emits them" do
    stream = ["a,be", "c,d"] |> to_stream
    result = Decoder.decode!(stream) |> Enum.to_list

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses empty lines into a list of token tuples" do
    stream = [",", "c,d"] |> to_stream
    result = Decoder.decode!(stream) |> Enum.to_list

    assert result == [["", ""], ~w(c d)]
  end

  test "parses partially populated lines into a list of token tuples" do
    stream = [",ci,\"\"", ",c,d"] |> to_stream
    result = Decoder.decode!(stream) |> Enum.to_list

    assert result == [["", "ci", ""], ["", "c", "d"]]
  end


  test "parses strings that contain single double quotes" do
    stream = ["a,be", "\"c\"\"\",d"] |> to_stream
    result = Decoder.decode!(stream) |> Enum.to_list

    assert result == [["a", "be"], ["c\"", "d"]]
  end

  test "parses strings that contain multi-byte unicode characters" do
    stream = ["a,b", "c,ಠ_ಠ"] |> to_stream
    result = CSV.decode!(stream) |> Enum.to_list

    assert result == [["a", "b"], ["c", "ಠ_ಠ"]]
  end

  test "delivers the correct number of rows" do
    stream = ["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"] |> to_stream
    result = Decoder.decode!(stream) |> Enum.count

    assert result == 6
  end

  test "delivers correctly ordered rows" do
    stream = [
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
    ] |> to_stream
    result = Decoder.decode!(stream, num_pipes: 3) |> Enum.to_list

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
