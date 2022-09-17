defmodule CSV.EncodingError do
  @moduledoc """
  Raised at runtime when the CSV encoding is invalid.
  """

  defexception [:line, :message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{
      line: line,
      message: message <> " on line " <> Integer.to_string(line)
    }
  end
end

defmodule CSV.RowLengthError do
  @moduledoc """
  Raised at runtime when the CSV has rows of variable length.
  """

  defexception [:line, :message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{
      line: line,
      message: message <> " on line " <> Integer.to_string(line)
    }
  end
end

defmodule CSV.StrayQuoteError do
  @moduledoc """
  Raised at runtime when the CSV row has stray quotes.
  """

  defexception [:line, :message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    field = options |> Keyword.fetch!(:field)

    message =
      "Stray quote on line " <>
        Integer.to_string(line) <> " near \"" <> field <> "\""

    %__MODULE__{
      line: line,
      message: message
    }
  end
end

defmodule CSV.EscapeSequenceError do
  @moduledoc """
  Raised at runtime when the CSV stream ends with unfinished escape sequences
  """

  defexception [:message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    escape_sequence = options |> Keyword.fetch!(:escape_sequence)
    escape_max_lines = options |> Keyword.fetch!(:escape_max_lines)

    message =
      "Escape sequence started on line #{line} " <>
        "near \"#{escape_sequence |> String.slice(0..9)}\" did not terminate.\n\n" <>
        "Escape sequences are allowed to span up to #{escape_max_lines} lines. " <>
        "This threshold avoids collecting the whole file into memory " <>
        "when an escape sequence does not terminate. You can change " <>
        "it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2"

    %__MODULE__{
      message: message
    }
  end
end
