defmodule DecodingTests.HeadersExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.Decoding.Decoder

  test "reports correct error when headers is false" do
    stream = ["a,b", "c"] |> to_line_stream()
    result = Decoder.decode(stream, headers: false, validate_row_length: true) |> Enum.to_list()

    assert result == [
             {:ok, ["a", "b"]},
             {:error, CSV.RowLengthError, [actual_length: 1, expected_length: 2, row: 2]}
           ]
  end

  test "reports correct error index when headers is true, error on index 1" do
    stream = ["a,b", "c"] |> to_line_stream()
    result = Decoder.decode(stream, headers: true, validate_row_length: true) |> Enum.to_list()

    assert result == [
             {:error, CSV.RowLengthError, [actual_length: 1, expected_length: 2, row: 2]}
           ]
  end

  test "reports correct error index when headers is true, error on index 2" do
    stream = ["a,b", "c,d", "e"] |> to_line_stream()
    result = Decoder.decode(stream, headers: true, validate_row_length: true) |> Enum.to_list()

    assert result == [
             {:ok, %{"a" => "c", "b" => "d"}},
             {:error, CSV.RowLengthError, [actual_length: 1, expected_length: 2, row: 3]}
           ]
  end

  test "reports correct error index when headers is a list" do
    stream = ["a"] |> to_line_stream()

    result =
      Decoder.decode(stream, headers: [:a, :b], validate_row_length: true) |> Enum.to_list()

    assert result == [
             {:error, CSV.RowLengthError, [actual_length: 1, expected_length: 2, row: 1]}
           ]
  end
end
