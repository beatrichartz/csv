defmodule CSVTest do
  use ExUnit.Case

  test "encodes" do
    result = CSV.encode([~w(a b), ~w(c d)]) |> Enum.take(2)
    assert result == ["a,b\r\n", "c,d\r\n"]
  end

  test "decodes" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    assert (CSV.decode!(stream) |> Enum.into([]) |> Enum.sort) == [~w(a be), ~w(c d)]
  end

  test "decodes emitting a stram of monads" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    assert (CSV.decode(stream) |> Enum.into([]) |> Enum.sort) == [ ok: ~w(a be), ok: ~w(c d) ]
  end
end
