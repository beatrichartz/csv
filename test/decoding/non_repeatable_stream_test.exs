defmodule DecodingTests.NonRepeatableStreamTest do
  use ExUnit.Case
  alias CSV.Decoding.Decoder

  @moduletag timeout: 1000

  test "decodes from a non-repeatable stream" do
    {:ok, out} =
      "a,b,c\nd,e,f"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> Decoder.decode
             |> Enum.to_list

    assert result == [ok: ~w(a b c), ok: ~w(d e f)]
  end

  test "decodes with headers from a non-repeatable stream" do
    {:ok, out} =
      "a,b,c\nd,e,f\ng,h,i"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> Decoder.decode(headers: true)
             |> Enum.to_list

    assert result == [
      ok: %{"a" => "d", "b" => "e", "c" => "f"},
      ok: %{"a" => "g", "b" => "h", "c" => "i"}
    ]
  end
end
