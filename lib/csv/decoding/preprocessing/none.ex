defmodule CSV.Decoding.Preprocessing.None do
  use CSV.Defaults

  @moduledoc ~S"""
  The CSV none preprocessor module - input = output.
  """

  @doc """
  Will pass on input unchanged
  """

  def process(stream, _ \\ []) do
    stream
  end
end
