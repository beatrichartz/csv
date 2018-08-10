defmodule DecodingTests.BaselineTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder

  doctest CSV.Decoding.Decoder

  test "parses lines into a list of fields" do
    stream = ["a,be", "c,d"] |> to_stream
    result = Decoder.decode(stream) |> Enum.to_list()

    assert result == [ok: ~w(a be), ok: ~w(c d)]
  end

  test "parses empty lines into a list of empty fields" do
    stream = [",", "c,d"] |> to_stream
    result = Decoder.decode(stream) |> Enum.to_list()

    assert result == [ok: ["", ""], ok: ~w(c d)]
  end

  test "parses partially populated lines into a list of fields" do
    stream = [",ci,\"\"", ",c,d"] |> to_stream
    result = Decoder.decode(stream) |> Enum.to_list()

    assert result == [ok: ["", "ci", ""], ok: ["", "c", "d"]]
  end

  test "parses strings that contain single double quotes" do
    stream = ["a,be", "\"c\"\"\",d"] |> to_stream
    result = Decoder.decode(stream) |> Enum.to_list()

    assert result == [ok: ["a", "be"], ok: ["c\"", "d"]]
  end

  test "parses strings that contain multi-byte unicode characters" do
    stream = ["a,b", "c,ಠ_ಠ"] |> to_stream
    result = Decoder.decode(stream) |> Enum.to_list()

    assert result == [ok: ["a", "b"], ok: ["c", "ಠ_ಠ"]]
  end

  test "delivers the correct number of rows" do
    stream = ["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"] |> to_stream
    result = Decoder.decode(stream) |> Enum.count()

    assert result == 6
  end

  test "delivers correctly ordered rows" do
    stream =
      [
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
      ]
      |> to_stream

    result = Decoder.decode(stream, num_workers: 3) |> Enum.to_list()

    assert result == [
             ok: ~w(a be),
             ok: ~w(c d),
             ok: ~w(e f),
             ok: ~w(g h),
             ok: ~w(i j),
             ok: ~w(k l),
             ok: ~w(m n),
             ok: ~w(o p),
             ok: ~w(q r),
             ok: ~w(s t),
             ok: ~w(u v),
             ok: ~w(w x),
             ok: ~w(y z)
           ]
  end
end
