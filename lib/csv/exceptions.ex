defmodule CSV.Parser.SyntaxError do
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

defmodule CSV.Lexer.EncodingError do
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

defmodule CSV.Decoder.StreamError do
  @moduledoc """
  Raised at runtime when the given stream is invalid.
  """

  defexception [:value, :message]

  def exception(options) do
    value   = options |> Keyword.fetch!(:value)
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{
      value: value,
      message: message 
    }
  end
end
