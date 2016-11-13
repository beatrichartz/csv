defmodule DecodingTests.StripFieldsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder

  @moduletag timeout: 1000

  test "parses strings and strips fields when given the option" do
    stream = ["  a , be", "c,    d\t"] |> to_stream
    result = Decoder.decode(stream, strip_fields: true) |> Enum.to_list

    assert result == [ok: ~w(a be), ok: ~w(c d)]
  end

end
