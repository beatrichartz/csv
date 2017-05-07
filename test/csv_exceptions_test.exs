defmodule CSVExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  alias CSV.RowLengthError

  test "decodes in normal mode emitting errors with rows" do
    stream = ~w(a,be a c,d) |> to_stream
    result = CSV.decode(stream) |> Enum.to_list
    assert result == [
      ok: ~w(a be),
      error: "Row has length 1 - expected length 2 on line 2",
      ok: ~w(c d)
    ]
  end

  test "decodes codepoints in normal mode emitting errors with rows" do
    stream = "a,be\na\nc,d\n" |> to_codepoints_stream

    result = CSV.decode(stream, preprocessor: :codepoints) |> Enum.to_list
    assert result == [
      ok: ~w(a be),
      error: "Row has length 1 - expected length 2 on line 2",
      ok: ~w(c d)
    ]
  end

  test "decodes in strict mode raising errors" do
    stream = ~w(a,be a c,d) |> to_stream

    assert_raise RowLengthError, fn ->
      CSV.decode!(stream) |> Stream.run
    end
  end

  test "decodes codepoints in strict mode raising errors" do
    stream = "a,be\na\nc,d\n" |> to_codepoints_stream

    assert_raise RowLengthError, fn ->
      CSV.decode!(stream, preprocessor: :codepoints) |> Stream.run
    end
  end
end
