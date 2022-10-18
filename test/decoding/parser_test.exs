defmodule DecodingTests.ParserTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Parser

  doctest CSV.Decoding.Parser

  test "parses lines into a list of fields" do
    stream = ["a,be", "c,d"] |> to_line_stream
    result = Parser.parse(stream) |> Enum.to_list()

    assert result == [ok: ~w(a be), ok: ~w(c d)]
  end

  1..20
  |> Enum.each(fn size ->
    @tag size: size
    test "parses byte streams of size #{size} into a list of fields", context do
      stream =
        "a,be\nc,d\ne,f\ngee this is a longer line,isn't it" |> to_byte_stream(context[:size])

      result = Parser.parse(stream) |> Enum.to_list()

      assert result == [
               ok: ~w(a be),
               ok: ~w(c d),
               ok: ~w(e f),
               ok: ["gee this is a longer line", "isn't it"]
             ]
    end
  end)

  test "parses empty lines into a list of empty fields" do
    stream = [",", "c,d"] |> to_line_stream
    result = Parser.parse(stream) |> Enum.to_list()

    assert result == [ok: ["", ""], ok: ~w(c d)]
  end

  test "parses partially populated lines into a list of fields" do
    stream = [",ci,\"\"", ",c,d"] |> to_line_stream
    result = Parser.parse(stream) |> Enum.to_list()

    assert result == [ok: ["", "ci", ""], ok: ["", "c", "d"]]
  end

  test "parses strings that contain single double quotes" do
    stream = ["a,be", "\"c\"\"\",d"] |> to_line_stream
    result = Parser.parse(stream) |> Enum.to_list()

    assert result == [ok: ["a", "be"], ok: ["c\"", "d"]]
  end

  test "parses strings that contain multi-byte unicode characters" do
    stream = ["a,b", "c,ಠ_ಠ"] |> to_line_stream
    result = Parser.parse(stream) |> Enum.to_list()

    assert result == [ok: ["a", "b"], ok: ["c", "ಠ_ಠ"]]
  end

  test "delivers the correct number of rows" do
    stream = ["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"] |> to_line_stream
    result = Parser.parse(stream) |> Enum.count()

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
      |> to_line_stream

    result = Parser.parse(stream) |> Enum.to_list()

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

  def encode_decode_loop(l, opts \\ []) do
    l |> CSV.encode(opts) |> Parser.parse(opts) |> Enum.to_list()
  end

  test "removes escaping for formula when unescape_formulas is set to true" do
    input = [["=1+1", ~S(=1+2";=1+2), ~S(=1+2'" ;,=1+2)], ["-10+7"], ["+10+7"], ["@A1:A10"]]

    assert encode_decode_loop([input], escape_formulas: true, unescape_formulas: true) == [
             ok: [
               "=1+1=1+2\";=1+2=1+2'\" ;,=1+2",
               "-10+7",
               "+10+7",
               "@A1:A10"
             ]
           ]
  end
end
