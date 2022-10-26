defmodule CSV.Defaults do
  @moduledoc ~S"""
  The module defaults of CSV.
  """

  defmacro __using__(_) do
    quote do
      @separator ?,
      @newline_character ?\n
      @newline <<@newline_character::utf8>>
      @carriage_return_character ?\r
      @carriage_return <<@carriage_return_character::utf8>>
      @escape_character ?"
      @escape <<@escape_character::utf8>>
      @escape_max_lines 10
      @replacement nil
      @force_escaping false
      @escape_formulas false
      @unescape_formulas false
      @escape_formula_start ["=", "-", "+", "@"]
    end
  end
end
