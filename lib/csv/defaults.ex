defmodule CSV.Defaults do
  @moduledoc ~S"""
  The module defaults of CSV.
  """

  defmacro __using__(_) do
    quote do
      @separator            ?,
      @newline              ?\n
      @carriage_return      ?\r
      @delimiter            << @carriage_return :: utf8 >> <> << @newline :: utf8 >>
      @double_quote         ?"
      @escape_max_lines     1000
      @replacement          nil
      @force_quotes         false
      @escape_formulas      false
      @escape_formula_start ["=", "-", "+", "@"]
    end
  end

  @doc """
  The default worker / work ratio.
  """
  def worker_work_ratio do
    5
  end

  @doc """
  The default number of workers used.
  """
  def num_workers do
    :erlang.system_info(:schedulers) * 3
  end
end
