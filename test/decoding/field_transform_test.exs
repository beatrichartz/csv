defmodule DecodingTests.FieldTransformTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder

  test "parses strings and applies a field transform when given the option" do
    stream = ["  a , be", "c,    d\t"] |> to_line_stream
    result = Decoder.decode(stream, field_transform: &String.trim/1) |> Enum.to_list()

    assert result == [ok: ~w(a be), ok: ~w(c d)]
  end
end
