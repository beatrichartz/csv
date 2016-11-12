defmodule DecodingTests.StripFieldsTest do
  use ExUnit.Case
  alias CSV.Decoder

  @moduletag timeout: 1000

  test "parses strings and strips fields when given the option" do
    stream = Stream.map(["  a , be", "c,    d\t"], &(&1))
    result = Decoder.decode!(stream, strip_cells: true) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

end
