defmodule DecodingTests.AppendRawLineTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder
  alias CSV.RowLengthError
  alias CSV.EscapeSequenceError
  alias CSV.StrayQuoteError
  alias CSV.EncodingError

  defp filter_errors(stream) do
    stream
    |> Stream.filter(fn
      {:error, _, _, _} -> true
      {:error, _, _, _, _} -> true
      _ -> false
    end)
  end
  
  test "produces meaningful errors for non-unicode files returning raw_file" do
    stream = "../fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!()

    errors = stream |> Decoder.decode(raw_line_on_error: true) |> filter_errors |> Enum.to_list()

    assert [
             {:error, EncodingError, "Invalid encoding", 0, invalid_string}
           ] = errors
    refute String.valid?(invalid_string)
  end
  
  test "includes an error for rows with variable length returning raw_file" do
    stream = ["a,\"be\"", ",c,d", "e,f", "g,,h", "i,j", "k,l"] |> to_stream

    errors = stream |> Decoder.decode(raw_line_on_error: true) |> filter_errors |> Enum.to_list()

    assert [
             {:error, RowLengthError, "Row has length 3 - expected length 2", 1, line1},
             {:error, RowLengthError, "Row has length 3 - expected length 2", 3, line2}
           ] = errors
    assert [line1, line2] |> Enum.all?(&String.valid?/1)
  end

  test "includes an error for rows with unescaped quotes returning raw_file" do
    stream = ["a\",\"be", "\"c,d", "\"e,f\"g\",h"] |> to_stream
    errors = stream |> Decoder.decode(raw_line_on_error: true) |> Enum.to_list()

    assert  [
             {:error, StrayQuoteError, "a", 0, line1},
             {:error, EscapeSequenceError, "c,d", 1, line2},
             {:error, StrayQuoteError, "e,f", 2, line3}
           ] = errors
    assert [line1, line2, line3] |> Enum.all?(&String.valid?/1)
  end
end
