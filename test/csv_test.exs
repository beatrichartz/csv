defmodule CSVTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  doctest CSV

  test "encodes" do
    result = CSV.encode([~w(a b), ~w(c d)]) |> Enum.take(2)
    assert result == ["a,b\r\n", "c,d\r\n"]
  end

  test "decodes in strict mode emitting rows as lists" do
    stream = ~w(a,be c,d) |> to_stream
    result = CSV.decode!(stream) |> Enum.to_list
    assert result == [~w(a be), ~w(c d)]
  end

  test "decodes a codepoints stream in normal mode emitting rows as lists" do
    stream = "a,be\r\nc,d\n" |> to_codepoints_stream
    result = CSV.decode!(stream, mode: :codepoints) |> Enum.to_list
    assert result == [
      ~w(a be),
      ~w(c d),
    ]
  end

  test "decodes in normal mode emitting tuples containing rows" do
    stream = ~w(a,be c,d) |> to_stream
    result = CSV.decode(stream) |> Enum.to_list
    assert result == [
      ok: ~w(a be),
      ok: ~w(c d),
    ]
  end

  test "decodes a codepoints stream in normal mode emitting tuples containing rows" do
    stream = "a,be\r\nc,d\n" |> to_codepoints_stream
    result = CSV.decode(stream, mode: :codepoints) |> Enum.to_list
    assert result == [
      ok: ~w(a be),
      ok: ~w(c d),
    ]
  end

end
