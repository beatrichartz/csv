defmodule DecodingTests.BaselineExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder
  alias CSV.RowLengthError
  alias CSV.EncodingError

  defp filter_errors(stream) do
    stream
    |> Stream.filter(fn
      {:error, _, _, _} -> true
      _ -> false
    end)
  end

  test "produces meaningful errors for non-unicode files" do
    stream = "../fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!()

    errors = stream |> Decoder.decode() |> filter_errors |> Enum.to_list()

    assert errors == [
             {:error, EncodingError, "Invalid encoding", 0}
           ]
  end

  test "invalid encoding can be replaced" do
    stream = [<<"a,", 255>>, "c,d"] |> to_stream
    result = Decoder.decode(stream, replacement: "?") |> Enum.take(2)

    assert result == [ok: ~w(a ?), ok: ~w(c d)]
  end

  test "discards any state in the current message queues when halted" do
    stream = ["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"] |> to_stream
    result = Decoder.decode(stream) |> Enum.take(2)

    assert result == [ok: ~w(a be), ok: ~w(c d)]

    next_result = Decoder.decode(stream) |> Enum.take(2)
    assert next_result == [ok: ~w(a be), ok: ~w(c d)]
  end

  test "empty stream input produces an empty stream as output" do
    stream = [] |> to_stream
    assert stream |> Decoder.decode() |> Enum.to_list() == []
  end

  test "can reuse the same stream" do
    stream =
      ["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"]
      |> to_stream
      |> Decoder.decode()

    result = stream |> Enum.take(2)

    assert result == [ok: ~w(a be), ok: ~w(c d)]

    next_result = stream |> Enum.take(2)
    assert next_result == [ok: ~w(a be), ok: ~w(c d)]
  end

  test "includes an error for rows with variable length" do
    stream = ["a,\"be\"", ",c,d", "e,f", "g,,h", "i,j", "k,l"] |> to_stream

    errors = stream |> Decoder.decode() |> filter_errors |> Enum.to_list()

    assert errors == [
             {:error, RowLengthError, "Row has length 3 - expected length 2", 1},
             {:error, RowLengthError, "Row has length 3 - expected length 2", 3}
           ]
  end

  def encode_decode_loop(l) do
    l |> CSV.encode() |> Decoder.decode() |> Enum.to_list()
  end

  test "does not get corrupted after an error" do
    assert_raise Protocol.UndefinedError, fn ->
      ~w(a) |> encode_decode_loop
    end

    result_a = [~w(b)] |> encode_decode_loop
    result_b = [~w(b)] |> encode_decode_loop
    result_c = [~w(b)] |> encode_decode_loop

    assert result_a == [ok: ~w(b)]
    assert result_b == [ok: ~w(b)]
    assert result_c == [ok: ~w(b)]
  end
end
