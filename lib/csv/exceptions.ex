defmodule CSV.RowLengthError do
  @moduledoc """
  Raised at runtime when the CSV has rows of variable length 
  and `validate_row_length` is set to true.
  """

  defexception [:row, :message]

  def exception(options) do
    row = options |> Keyword.fetch!(:row)
    actual_length = options |> Keyword.fetch!(:actual_length)
    expected_length = options |> Keyword.fetch!(:expected_length)

    %__MODULE__{
      row: row,
      message:
        "Row #{row} has length #{actual_length} instead of expected length #{expected_length}\n\n" <>
          "You are seeing this error because :validate_row_length has been set to true\n"
    }
  end
end

defmodule CSV.StrayEscapeCharacterError do
  @moduledoc """
  Raised at runtime when the CSV row has stray quotes.
  """

  defexception [:line, :sequence_position, :message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    sequence = options |> Keyword.fetch!(:sequence)

    message =
      "Stray escape character on line #{line}:" <>
        "\n\n#{sequence}" <>
        "\n\nThis error often happens when the wrong separator or escape character has been applied.\n"

    %__MODULE__{
      line: line,
      message: message
    }
  end
end

defmodule CSV.EscapeSequenceError do
  @moduledoc """
  Raised at runtime when the CSV stream either ends with unfinished escape sequences or
  escape sequences span more lines than specified by escape_max_lines (default 1000).
  """

  defexception [:line, :escape_sequence_start_line, :message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    stream_halted = options |> Keyword.get(:stream_halted, false)
    escape_sequence_start = options |> Keyword.fetch!(:escape_sequence_start)
    mode = options |> Keyword.fetch!(:mode)

    continues_parsing =
      if mode == :normal do
        " Parsing will continue on line #{line + 1}."
      else
        " You can use normal mode to continue parsing rows even if single rows have errors."
      end

    message =
      if stream_halted do
        "Escape sequence started on line #{line}:" <>
          "\n\n#{escape_sequence_start}\n\ndid not terminate before the stream halted." <>
          continues_parsing <> "\n"
      else
        escape_max_lines = options |> Keyword.fetch!(:escape_max_lines)

        "Escape sequence started on line #{line}:" <>
          "\n\n#{escape_sequence_start}\n\ndid not terminate." <>
          continues_parsing <>
          "\n\n" <>
          "Escape sequences are allowed to span up to #{escape_max_lines} lines. " <>
          "This threshold avoids collecting the whole file into memory " <>
          "when an escape sequence does not terminate.\nYou can change " <>
          "it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2\n"
      end

    %__MODULE__{
      message: message
    }
  end
end
