defmodule CSV.SyntaxError do
  @moduledoc """
  Raised at runtime when the CSV syntax is invalid.
  """

  defexception [:line, :message]

  def exception(options) do
    line    = options |> Keyword.fetch!(:line)
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{
      line: line,
      message: message <> " on line " <> Integer.to_string(line)
    }
  end
end

defmodule CSV.EncodingError do
  @moduledoc """
  Raised at runtime when the CSV encoding is invalid.
  """

  defexception [:line, :message]

  def exception(options) do
    line    = options |> Keyword.fetch!(:line)
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
    line    = options |> Keyword.fetch!(:line)
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{
      line: line,
      message: message <> " on line " <> Integer.to_string(line)
    }
  end
end

defmodule CSV.UnfinishedEscapeSequenceError do
  @moduledoc """
  Raised at runtime when the CSV stream ends with unfinished escape sequences
  """

  defexception [:message]

  def exception(options) do
    line = options |> Keyword.fetch!(:line)
    escape_sequence = options |> Keyword.fetch!(:escape_sequence)
    num_escaped_lines = options |> Keyword.fetch!(:num_escaped_lines)
    escape_max_lines = options |> Keyword.fetch!(:escape_max_lines)

    message = "Escape sequence started on line #{line} " <>
        "near \"#{escape_sequence |> String.slice(0..9)}\" " <>
        "#{num_escaped_lines |> line_spanning_message}did not terminate"

    message = if num_escaped_lines == escape_max_lines do
      message <>
        "\n\nMaximum number of escaped lines reached\n" <>
        "Escape sequences are allowed to span up to #{escape_max_lines} lines. " <>
        "This threshold avoids collecting the whole file into memory " <>
        "when an escape sequence does not terminate. You can change " <>
        "it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2"
    else
      message
    end

    %__MODULE__{
      message: message
    }
  end

  defp line_spanning_message(0) do
    ""
  end
  defp line_spanning_message(1) do
    "spanning 1 line "
  end
  defp line_spanning_message(num_lines) do
    "spanning #{num_lines} lines "
  end
end
