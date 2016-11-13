defmodule DecodingTests.SeparatorsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder

  @moduletag timeout: 1000

  test "parses strings separated by custom separators into a list of token tuples and emits them" do
    stream = ["a;be", "c;d"] |> to_stream
    result = Decoder.decode(stream, separator: ?;) |> Enum.to_list

    assert result == [ok: ~w(a be), ok: ~w(c d)]
  end

  test "parses strings separated by custom tab separators into a list of token tuples and emits them" do
    stream = ["a\tbe", "c\td"] |> to_stream
    result = Decoder.decode(stream, separator: ?\t) |> Enum.to_list

    assert result == [ok: ~w(a be), ok: ~w(c d)]
  end

end
