defmodule CSVExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.RowLengthError

  test "decodes in normal mode emitting errors with rows" do
    stream = ~w(a,be a c,d) |> to_stream
    result = CSV.decode(stream) |> Enum.to_list()

    assert result == [
             ok: ~w(a be),
             error: "Row has length 1 - expected length 2 on line 2",
             ok: ~w(c d)
           ]
  end

  test "decodes in normal mode not emitting errors for row length when row length validation is disabled" do
    stream = ~w(a,be a c,d) |> to_stream
    result = CSV.decode(stream, [validate_row_length: false]) |> Enum.to_list
    assert result == [
      ok: ~w(a be),
      ok: ~w(a),
      ok: ~w(c d)
    ]
  end

  test "decodes in strict mode raising errors" do
    stream = ~w(a,be a c,d) |> to_stream

    assert_raise RowLengthError, fn ->
      CSV.decode!(stream) |> Stream.run()
    end
  end

  test "decodes in strict mode not raising errors on variable row length if row length validation is disabled" do
    stream = ~w(a,be a c,d) |> to_stream

    CSV.decode!(stream, [validate_row_length: false]) |> Stream.run
  end

end
