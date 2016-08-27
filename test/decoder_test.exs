defmodule DecoderTest do
  use ExUnit.Case
  alias CSV.Decoder
  alias CSV.Parser.SyntaxError
  alias CSV.Lexer.EncodingError
  alias CSV.Decoder.RowLengthError
  alias CSV.LineAggregator.CorruptStreamError

  doctest Decoder

  @moduletag timeout: 1000

  defp filter_errors(stream) do
    stream |> Stream.filter(fn
      { :error, _ } -> true
      _ -> false
    end)
  end

  test "decodes from a StringIO stream" do
    {:ok, out} =
      "a,b,c\nd,e,f"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> CSV.decode!
             |> Enum.into([])

    assert result == [~w(a b c), ~w(d e f)]
  end

  test "decodes with headers from a StringIO stream" do
    {:ok, out} =
      "a,b,c\nd,e,f\ng,h,i"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> CSV.decode!(headers: true)
             |> Enum.into([])

    assert result == [
      %{"a" => "d", "b" => "e", "c" => "f"},
      %{"a" => "g", "b" => "h", "c" => "i"}
    ]
  end

    test "decodes with headers from a StringIO stream and drop n lines" do
    {:ok, out} =
      "#comment1\n,#comment2\naa,bb,cc\nd,e,f\ng,h,i"
      |> StringIO.open

    result = out
             |> IO.binstream(:line)
             |> CSV.decode!(headers: true, drop_rows: 2)
             |> Enum.into([])

    assert result == [
      %{"aa" => "d", "bb" => "e", "cc" => "f"},
      %{"aa" => "g", "bb" => "h", "cc" => "i"}
    ]
  end

  test "parses strings into a list of token tuples and emits them" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses empty lines into a list of token tuples" do
    stream = Stream.map([",", "c,d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [["", ""], ~w(c d)]
  end

  test "parses partially populated lines into a list of token tuples" do
    stream = Stream.map([",ci,\"\"", ",c,d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [["", "ci", ""], ["", "c", "d"]]
  end

  test "parses strings separated by custom separators into a list of token tuples and emits them" do
    stream = Stream.map(["a;be", "c;d"], &(&1))
    result = Decoder.decode!(stream, separator: ?;) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings separated by custom tab separators into a list of token tuples and emits them" do
    stream = Stream.map(["a\tbe", "c\td"], &(&1))
    result = Decoder.decode!(stream, separator: ?\t) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings and strips cells when given the option" do
    stream = Stream.map(["  a , be", "c,    d\t"], &(&1))
    result = Decoder.decode!(stream, strip_cells: true) |> Enum.into([])

    assert result == [~w(a be), ~w(c d)]
  end

  test "parses strings into maps when headers are set to true" do
    stream = Stream.map(["a,be", "c,d", "e,f"], &(&1))
    result = Decoder.decode!(stream, headers: true) |> Enum.into([])

    assert result |> Enum.sort == [
      %{"a" => "c", "be" => "d"},
      %{"a" => "e", "be" => "f"}
    ]
  end

  test "parses strings and strips cells when headers are given and strip_cells is true" do
    stream = Stream.map(["h1,h2", "a, be free ", "c,d"], &(&1))
    result = Decoder.decode!(stream, headers: true, strip_cells: true) |> Enum.into([])

    assert result == [
      %{"h1" => "a", "h2" => "be free"},
      %{"h1" => "c", "h2" => "d"}
    ]
  end

  test "parses strings into maps when headers are given as a list" do
    stream = Stream.map(["a,be", "c,d"], &(&1))
    result = Decoder.decode!(stream, headers: [:a, :b]) |> Enum.into([])

    assert result == [
      %{:a => "a", :b => "be"},
      %{:a => "c", :b => "d"}
    ]
  end

  test "parses strings that contain single double quotes" do
    stream = Stream.map(["a,be", "\"c\"\"\",d"], &(&1))
    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [["a", "be"], ["c\"", "d"]]
  end

  test "parses strings unless they contain unfinished escape sequences" do
    stream = Stream.map(["a,be", "\"c,d"], &(&1))
    assert_raise CorruptStreamError, fn ->
      Decoder.decode!(stream, headers: [:a, :b]) |> Enum.into([])
    end
  end

  test "parses strings that contain multi-byte unicode characters" do
    stream = Stream.map(["a,b", "c,ಠ_ಠ"], &(&1))
    result = CSV.decode!(stream) |> Enum.into([])

    assert result == [["a", "b"], ["c", "ಠ_ಠ"]]
  end

  test "produces meaningful errors for non-unicode files" do
    stream = "./fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!

    assert_raise EncodingError, fn ->
      CSV.decode!(stream) |> Enum.into([]) |> Enum.sort
    end
  end

  test "emitted monads include an error for non-unicode files" do
    stream = "./fixtures/broken-encoding.csv" |> Path.expand(__DIR__) |> File.stream!

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

  test "delivers the correct number of rows" do
    stream = Stream.map(["a,be", "c,d", "e,f", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode!(stream) |> Enum.count

    assert result == 6
  end

  test "collects rows with fields spanning multiple lines" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))
    result = Decoder.decode!(stream) |> Enum.take(2)

    assert result == [["a", "be\r\nc,d\r\ne,f"], ~w(g h)]
  end

  test "collects rows with fields spanning multiple lines and raises an error if they are unfinished" do
    stream = Stream.map([",ci,\"\"\"", ",c,d"], &(&1))

    assert_raise CorruptStreamError, fn ->
      Decoder.decode!(stream) |> Stream.run
    end
  end

  test "collects rows with fields and complex escape sequences spanning multiple lines" do
    stream = Stream.map([
      # line 1
      ",,\"",
      "field three of line one",
      "contains \"\"quoted\"\" text, ",
      "multiple \"\"linebreaks\"\"",
      "and ends on a new line.\"",
      # line 2
      "line two has,\"a simple, quoted second field",
      "with one newline\",and a standard third field",
      # line 3
      "\"line three begins with an escaped field,",
      " continues with\",\"an escaped field,",
      "and ends\",\"with",
      "an escaped field\"",
      # line 4
      "\"field two in",
      "line four\",\"",
      "begins and ends with a newline",
      "\",\", and field three",
      "\"\"\"\"",
      "is full of newlines and quotes\n\"",
      # line 5
      "\"line five has an empty line in field two\",\"",
      "",
      "\",\"\"\"and a doubly quoted third field",
      # line 6 only contains quotes and new lines
      "\"\"\"",
      "\"\"\"\"\"\",\"\"\"",
      "\"\"\"\"",
      "\",\"\"\"\"",
      # line 7
      "line seven has an intermittent,\"quote",
      "right after",
      "\"\"a new line",
      "and",
      "ends with a standard, \"\"\",unquoted third field"
    ], &(&1))

    result = Decoder.decode!(stream) |> Enum.into([])

    assert result == [
      [
        "",
        "",
        "\r\nfield three of line one\r\ncontains \"quoted\" text, \r\nmultiple \"linebreaks\"\r\nand ends on a new line."
      ],
      [
        "line two has",
        "a simple, quoted second field\r\nwith one newline",
        "and a standard third field"
      ],
      [
        "line three begins with an escaped field,\r\n continues with",
        "an escaped field,\r\nand ends",
        "with\r\nan escaped field"
      ],
      [
        "field two in\r\nline four",
        "\r\nbegins and ends with a newline\r\n",
        ", and field three\r\n\"\"\r\nis full of newlines and quotes\n"
      ],
      [
        "line five has an empty line in field two",
        "\r\n\r\n",
        "\"and a doubly quoted third field\r\n\""
      ],
      [
        "\"\"",
        "\"\r\n\"\"\r\n",
        "\""
      ],
      [
        "line seven has an intermittent",
        "quote\r\nright after\r\n\"a new line\r\nand\r\nends with a standard, \"",
        "unquoted third field"
      ]

    ]
  end


  test "does not collect rows with fields spanning multiple lines if multiline_escape is false" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))

    assert_raise SyntaxError, fn ->
      Decoder.decode!(stream, multiline_escape: false) |> Stream.run
    end
  end

  test "emitted monads include an error for each row with fields spanning multiple lines if multiple_escape is false" do
    stream = Stream.map(["a,\"be", "c,d", "e,f\"", "g,h", "i,j", "k,l"], &(&1))

    errors = stream |> Decoder.decode(multiline_escape: false) |> filter_errors |> Enum.into([])
    assert errors == [
      error: "Unterminated escape sequence near 'be'",
      error: "Unterminated escape sequence near 'f'"
    ]
  end

  test "raises an error if rows are of variable length" do
    stream = Stream.map(["a,\"be\"", ",c,d", "e,f", "g,,h", "i,j", "k,l"], &(&1))

    assert_raise RowLengthError, fn ->
      Decoder.decode!(stream) |> Stream.run
    end
  end

  test "emitted monads include an error for rows with variable length" do
    stream = Stream.map(["a,\"be\"", ",c,d", "e,f", "g,,h", "i,j", "k,l"], &(&1))

    errors = stream |> Decoder.decode |> filter_errors |> Enum.into([])
    assert errors == [
      error: "Encountered a row with length 3 instead of 2",
      error: "Encountered a row with length 3 instead of 2"
    ]
  end

  test "delivers correctly ordered rows" do
    stream = Stream.map([
      "a,be",
      "c,d",
      "e,f",
      "g,h",
      "i,j",
      "k,l",
      "m,n",
      "o,p",
      "q,r",
      "s,t",
      "u,v",
      "w,x",
      "y,z"
    ], &(&1))
    result = Decoder.decode!(stream, num_pipes: 3) |> Enum.into([])

    assert result ==  [
      ~w(a be),
      ~w(c d),
      ~w(e f),
      ~w(g h),
      ~w(i j),
      ~w(k l),
      ~w(m n),
      ~w(o p),
      ~w(q r),
      ~w(s t),
      ~w(u v),
      ~w(w x),
      ~w(y z),
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
