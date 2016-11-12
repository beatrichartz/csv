defmodule DecodingTests.BaselineExceptionsTest do
  use ExUnit.Case
  alias CSV.Decoder
  alias CSV.Lexer.EncodingError
  alias CSV.Decoder.RowLengthError

  @moduletag timeout: 1000

  defp filter_errors(stream) do
    stream |> Stream.filter(fn
      { :error, _ } -> true
      _ -> false
    end)
  end

  test "raises meaningful errors for non-unicode files" do
    stream = "../fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!

    assert_raise EncodingError, fn ->
      CSV.decode!(stream) |> Enum.into([]) |> Enum.sort
    end
  end

  test "produces meaningful errors for non-unicode files" do
    stream = "../fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!

    errors = stream |> Decoder.decode |> filter_errors |> Enum.into([])
    assert errors == [
      error: "Invalid encoding"
    ]
  end

  test "discards any state in the current message queues when halted" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode!(stream) |> Enum.take(2)

    assert result == [~w(a be), ~w(c d)]

    next_result = Decoder.decode!(stream) |> Enum.take(2)
    assert next_result == [~w(a be), ~w(c d)]
  end

  test "empty stream input produces an empty stream as output" do
    stream = Stream.map([], &(&1))
              |> Decoder.decode!
    assert stream |> Enum.into([]) == []
  end

  test "can reuse the same stream" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
             |> Decoder.decode!
    result = stream |> Enum.take(2)

    assert result == [~w(a be), ~w(c d)]

    next_result = stream |> Enum.take(2)
    assert next_result == [~w(a be), ~w(c d)]
  end

  test "raises an error if rows are of variable length" do
    stream = Stream.map(["a,\"be\"", ",c,d", "e,f", "g,,h", "i,j", "k,l"], &(&1))

    assert_raise RowLengthError, fn ->
      Decoder.decode!(stream) |> Stream.run
    end
  end

  test "includes an error for rows with variable length" do
    stream = Stream.map(["a,\"be\"", ",c,d", "e,f", "g,,h", "i,j", "k,l"], &(&1))

    errors = stream |> Decoder.decode |> filter_errors |> Enum.into([])
    assert errors == [
      error: "Encountered a row with length 3 instead of 2",
      error: "Encountered a row with length 3 instead of 2"
    ]
  end

  def encode_decode_loop(l) do
    l |> CSV.encode |> CSV.decode! |> Enum.to_list
  end
  test "does not get corrupted after an error" do
    assert_raise Protocol.UndefinedError, fn ->
      ~w(a) |> encode_decode_loop
    end
    result_a = [~w(b)] |> encode_decode_loop
    result_b = [~w(b)] |> encode_decode_loop
    result_c = [~w(b)] |> encode_decode_loop

    assert result_a == [~w(b)]
    assert result_b == [~w(b)]
    assert result_c == [~w(b)]
  end

end
