defmodule DecodingTests.PreprocessingTests.NoneTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Preprocessing.None

  test "does pass the input to the output directly" do
    stream = ~w(g,h i,j k,l) |> to_stream
    aggregated = stream |> None.process |> Enum.to_list
    assert aggregated == [
      "g,h",
      "i,j",
      "k,l"
    ]
  end

end
