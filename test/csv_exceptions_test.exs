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

  test "decodes in normal mode not emitting errors with rows using row_length variable" do
    stream = ~w(a,be a c,d) |> to_stream
    result = CSV.decode(stream,[row_length: :variable]) |> Enum.to_list
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

  test "decodes in strict mode not raising errors using row_length variable" do
    stream = ~w(a,be a c,d) |> to_stream

    CSV.decode!(stream,[row_length: :variable]) |> Stream.run
  end

end
