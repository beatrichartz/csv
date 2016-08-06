defmodule CSV.Defaults do
  @moduledoc ~S"""
  The module defaults of CSV.
  """

  defmacro __using__(_) do
    quote do
      @separator                  ?,
      @newline                    ?\n
      @carriage_return            ?\r
      @delimiter                  << @carriage_return :: utf8 >> <> << @newline :: utf8 >>
      @double_quote               ?"
      @multiline_escape_max_lines 1000
    end
  end

  def worker_work_ratio do
    5
  end

  def num_workers do
    :erlang.system_info(:schedulers) * 3
  end

end
