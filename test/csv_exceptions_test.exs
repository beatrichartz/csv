defmodule CSVExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.RowLengthError

  test "decodes in normal mode emitting errors with rows" do
    stream = ~w(a,be a c,d) |> to_line_stream
    result = CSV.decode(stream, validate_row_length: true) |> Enum.to_list()

    assert result == [
             ok: ~w(a be),
             error:
               "Row 2 has length 1 instead of expected length 2\n\n" <>
                 "You are seeing this error because :validate_row_length has been set to true\n",
             ok: ~w(c d)
           ]
  end

  test "decodes in strict mode raising errors" do
    stream = ~w(a,be a c,d) |> to_line_stream

    assert_raise RowLengthError, fn ->
      CSV.decode!(stream, validate_row_length: true) |> Stream.run()
    end
  end

  test "returns encoding errors as is with rows in normal mode" do
    stream = [<<"Diego,Fern", 225, "ndez">>, "John,Smith"] |> to_line_stream
    result = CSV.decode(stream) |> Enum.to_list()

    assert result == [
             ok: ["Diego", <<"Fern", 225, "ndez">>],
             ok: ~w(John Smith)
           ]
  end
end
