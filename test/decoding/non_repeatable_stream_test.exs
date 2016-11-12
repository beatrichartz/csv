defmodule DecodingTests.NonRepeatableStreamTest do
  use ExUnit.Case
  alias CSV.Decoder

  @moduletag timeout: 1000

  test "decodes from a non-repeatable stream" do
    {:ok, out} =
      "a,b,c\nd,e,f"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> Decoder.decode!
             |> Enum.into([])

    assert result == [~w(a b c), ~w(d e f)]
  end

  test "decodes with headers from a non-repeatable stream" do
    {:ok, out} =
      "a,b,c\nd,e,f\ng,h,i"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> Decoder.decode!(headers: true)
             |> Enum.into([])

    assert result == [
      %{"a" => "d", "b" => "e", "c" => "f"},
      %{"a" => "g", "b" => "h", "c" => "i"}
    ]
  end
end
