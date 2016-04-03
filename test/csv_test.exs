defmodule CSVTest do
  use ExUnit.Case
  doctest CSV

  test "encodes" do
    result = CSV.encode([~w(a b), ~w(c d)]) |> Enum.take(2)
    assert result == ["a,b\r\n", "c,d\r\n"]
  end

  test "decodes" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = CSV.decode(stream) |> Enum.into([]) |> Enum.sort

    assert result == [~w(a be), ~w(c d)]
  end

end
