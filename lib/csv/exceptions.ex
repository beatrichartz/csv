defmodule CSV.Parser.SyntaxError do
  @moduledoc """
  Raised at runtime when the CSV syntax is invalid.
  """

  defexception [:line, :message]

  def exception(options) do
    line    = options |> Keyword.fetch!(:line)
    message = options |> Keyword.fetch!(:message)

    %__MODULE__{line: line, message: message}
  end
end
