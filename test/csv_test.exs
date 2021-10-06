defmodule CSVTest do
  use ExUnit.Case
  use CSV.Defaults
  import TestSupport.StreamHelpers

  doctest CSV

  test "encodes" do
    result = CSV.encode([~w(a b), ~w(c d)]) |> Enum.take(2)
    assert result == ["a,b\r\n", "c,d\r\n"]
  end

  test "decodes in strict mode emitting rows as lists" do
    stream = ~w(a,be c,d) |> to_stream
    result = CSV.decode!(stream) |> Enum.to_list()
    assert result == [~w(a be), ~w(c d)]
  end

  test "decodes in normal mode emitting tuples containing rows" do
    stream = ~w(a,be c,d) |> to_stream
    result = CSV.decode(stream) |> Enum.to_list()

    assert result == [
             ok: ~w(a be),
             ok: ~w(c d)
           ]
  end

  test "decodes in strict mode not raising validation errors on variable row length if row length validation is disabled" do
    stream = ~w(a,be a c,d) |> to_stream

    CSV.decode!(stream, validate_row_length: false) |> Stream.run()
  end

  test "decodes in normal mode not not validating row length when row length validation is disabled" do
    stream = ~w(a,be a c,d) |> to_stream
    result = CSV.decode(stream, validate_row_length: false) |> Enum.to_list()

    assert result == [
             ok: ~w(a be),
             ok: ~w(a),
             ok: ~w(c d)
           ]
  end

  test "uses the :lines preprocessor by default" do
    stream = ~w(g,"h i,j" k,l) |> to_stream
    result = CSV.decode(stream) |> Enum.to_list()

    assert result == [
             ok: ["g", "h\r\ni,j"],
             ok: ["k", "l"]
           ]
  end

  test "uses the :none preprocessor if specified" do
    stream = ~w(g,"h i,j" k,l) |> to_stream
    result = CSV.decode(stream, preprocessor: :none) |> Enum.to_list()

    assert result == [
             error:
               CSV.EscapeSequenceError.exception(
                 escape_sequence: "h",
                 line: 1,
                 escape_max_lines: @escape_max_lines
               ).message,
             error:
               CSV.StrayQuoteError.exception(
                 field: "j",
                 line: 2
               ).message,
             ok: ["k", "l"]
           ]
  end
end
