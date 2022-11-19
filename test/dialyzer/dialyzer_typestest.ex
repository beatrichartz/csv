defmodule DialyzerTypetest do
  @moduledoc "This is a module to test type definitions"

  def test_decode_option_escape_character do
    ["dummy,input"] |> CSV.decode(escape_character: ?.) |> Enum.to_list()
  end

  def test_decode_option_separator do
    ["dummy,input"] |> CSV.decode(separator: ?.) |> Enum.to_list()
  end

  def test_decode_option_unescape_formulas do
    ["dummy,input"] |> CSV.decode(unescape_formulas: true) |> Enum.to_list()
  end

  def test_decode_option_escape_max_lines do
    ["dummy,input"] |> CSV.decode(escape_max_lines: 10) |> Enum.to_list()
  end

  def test_decode_option_validate_row_length do
    ["dummy,input"] |> CSV.decode(validate_row_length: true) |> Enum.to_list()
  end

  def test_decode_option_field_transform do
    ["dummy,input"] |> CSV.decode(field_transform: fn s -> s end) |> Enum.to_list()
  end

  def test_decode_option_headers_list do
    ["dummy,input"] |> CSV.decode(headers: ["a", "b"]) |> Enum.to_list()
  end

  def test_decode_option_headers_atom_list do
    ["dummy,input"] |> CSV.decode(headers: [:a, :b]) |> Enum.to_list()
  end

  def test_encode_option_separator do
    ["dummy", "input"] |> CSV.encode(separator: true) |> Enum.to_list()
  end

  def test_encode_option_escape_character do
    ["dummy", "input"] |> CSV.encode(escape_character: ?") |> Enum.to_list()
  end

  def test_encode_option_escape_formulas do
    ["dummy", "input"] |> CSV.encode(escape_formulas: true) |> Enum.to_list()
  end

  def test_encode_option_force_escaping do
    ["dummy", "input"] |> CSV.encode(force_escaping: true) |> Enum.to_list()
  end

  def test_encode_option_headers_list do
    ["dummy", "input"] |> CSV.encode(headers: ["a", "b"]) |> Enum.to_list()
  end

  def test_encode_option_headers_atom_list do
    ["dummy", "input"] |> CSV.encode(headers: [:a, :b]) |> Enum.to_list()
  end

  def test_encode_option_headers_keyword_list do
    [%{a: "value!", b: "value!"}] |> CSV.encode(headers: [a: "x", b: "y"]) |> Enum.to_list()
  end
end
