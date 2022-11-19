defmodule ParseTypespectest do
  @moduledoc "Test parser typespecs"

  alias CSV.Decoding.Parser

  def test_parse_option_escape_character do
    ["dummy,input"] |> Parser.parse(escape_character: ?.) |> Enum.to_list()
  end

  def test_decode_option_separator do
    ["dummy,input"] |> Parser.parse(separator: ?.) |> Enum.to_list()
  end

  def test_decode_option_unescape_formulas do
    ["dummy,input"] |> Parser.parse(unescape_formulas: true) |> Enum.to_list()
  end

  def test_decode_option_escape_max_lines do
    ["dummy,input"] |> Parser.parse(escape_max_lines: 10) |> Enum.to_list()
  end

  def test_decode_option_field_transform do
    ["dummy,input"] |> Parser.parse(field_transform: fn s -> s end) |> Enum.to_list()
  end
end
