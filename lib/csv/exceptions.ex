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

defmodule CSV.CorruptStreamError do
  @moduledoc """
  Raised at runtime when the CSV stream ends with unfinished escape sequences
  """

  defexception [:message]

  def exception(options) do
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{
      message: message
    }
  end
end
