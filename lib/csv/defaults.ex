defmodule CSV.Defaults do
  @moduledoc ~S"""
  The module defaults of CSV.
  """

  defmacro __using__(_) do
    quote do
      @separator       ","
      @newline         "\n"
      @carriage_return "\r"
      @delimiter       @carriage_return <> @newline
      @double_quote    "\""
    end
  end

end
