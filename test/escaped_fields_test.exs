defmodule EscapedFieldsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  test "collects rows with fields spanning multiple lines" do
    stream = ~w(a,"be c,d e,f" g,h i,j k,l) |> to_stream
    result = CSV.decode!(stream) |> Enum.take(2)

    assert result == [["a", "be\r\nc,d\r\ne,f"], ~w(g h)]
  end

  test "collects rows with fields and escape sequences spanning multiple lines" do
    stream = [
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
      "is full of newlines and quotes\r\n\"",
      # line 5
      "\"line five has an empty line in field two\",\"",
      "",
      "\",\"\"\"and a doubly quoted third field",
      "\"\"\"",
      # line 6 only contains quotes and new lines
      "\"\"\"\"\"\",\"\"\"",
      "\"\"\"\"",
      "\",\"\"\"\"",
      # line 7
      "line seven has an intermittent,\"quote",
      "right after",
      "\"\"a new line",
      "and",
      "ends with a standard, \"\"\",unquoted third field"
    ] |> to_stream

    result = CSV.decode!(stream) |> Enum.to_list

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
        ", and field three\r\n\"\"\r\nis full of newlines and quotes\r\n"
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

end
