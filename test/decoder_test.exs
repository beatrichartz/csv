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
    result = Decoder.decode(stream, separator: ?;) |> Enum.into([]) |> Enum.sort

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

    assert result |> Enum.sort == [
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

  test "parses strings that contain multi-byte unicode characters" do
    stream = Stream.map(["a,b", "c,ಠ_ಠ"], &(&1))
    result = CSV.decode(stream) |> Enum.into([]) |> Enum.sort

    assert result == [["a", "b"], ["c", "ಠ_ಠ"]]
  end

  test "produces meaningful errors for non-unicode files" do
    stream = "./fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!
    assert_raise CSV.Lexer.EncodingError, fn ->
      result = CSV.decode(stream) |> Enum.into([]) |> Enum.sort
    end
  end

  test "discards any state in the current message queues when halted" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode(stream, num_pipes: 1) |> Enum.take(2)

    assert result == [~w(a be), ~w(c d)]

    next_result = Decoder.decode(stream, num_pipes: 1) |> Enum.take(2)
    assert next_result == [~w(a be), ~w(c d)]
  end

  test "delivers the correct number of rows" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode(stream, num_pipes: 1) |> Enum.count

    assert result ==  6
  end

  test "delivers correctly ordered rows with num_pipes 1" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode(stream, num_pipes: 1) |> Enum.into([])

    assert result ==  [~w(a be), ~w(c d), ~w(e f), ~w(g h), ~w(i j), ~w(k l)]
  end

  def encode_decode_loop(l) do
    l |> CSV.encode |> CSV.decode(num_pipes: 1) |> Enum.to_list
  end
  test "does not get corrupted after an error" do
    assert_raise CSV.Decoder.StreamError, fn ->
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
