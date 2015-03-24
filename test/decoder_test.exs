defmodule DecoderTest do
  use ExUnit.Case
  alias CSV.Decoder, as: Decoder

  test "parses strings into a list of token tuples and emits them" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = Decoder.decode(stream) |> Enum.into([]) |> Enum.sort

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings separated by custom separators into a list of token tuples and emits them" do
    stream = Stream.map(["a;be", "c;d"], &(&1))
    result = Decoder.decode(stream, separator: ";") |> Enum.into([]) |> Enum.sort

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings and strips cells when given the option" do
    stream = Stream.map(["  a , be", "c,    d\t"], &(&1))
    result = Decoder.decode(stream, strip_cells: true) |> Enum.into([]) |> Enum.sort

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings into maps when headers are set to true" do
    stream = Stream.map(["a,be", "c,d", "e,f"], &(&1))
    result = Decoder.decode(stream, headers: true) |> Enum.into([]) |> Enum.sort

    assert result == [
      %{"a" => "c", "be" => "d"},
      %{"a" => "e", "be" => "f"}
    ]
  end

  test "parses strings into maps when headers are given as a list" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = Decoder.decode(stream, headers: [:a, :b]) |> Enum.into([]) |> Enum.sort

    assert result == [
      %{:a => "a", :b => "be"},
      %{:a => "c", :b => "d"}
    ]
  end

  test "parses strings that contain single double quotes" do
    stream = Stream.map(["a,be", "c\",d"], &(&1))
    result = Decoder.decode(stream) |> Enum.into([]) |> Enum.sort

    assert result == [["a", "be"], ["c\"", "d"]]
  end

  test "parses strings unless they contain unfinished escape sequences" do
    stream = Stream.map(["a,be", "\"c,d"], &(&1))
    assert_raise CSV.Parser.SyntaxError, fn ->
      Decoder.decode(stream, headers: [:a, :b]) |> Enum.into([])
    end
  end

end
