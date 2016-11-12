defmodule DecodingTests.SeparatorsTest do
  use ExUnit.Case
  alias CSV.Decoder

  @moduletag timeout: 1000

  test "parses strings separated by custom separators into a list of token tuples and emits them" do
    stream = Stream.map(["a;be", "c;d"], &(&1))
    result = Decoder.decode!(stream, separator: ?;) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings separated by custom tab separators into a list of token tuples and emits them" do
    stream = Stream.map(["a\tbe", "c\td"], &(&1))
    result = Decoder.decode!(stream, separator: ?\t) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

end
