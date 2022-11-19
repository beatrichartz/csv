defmodule EncodeTypespectest do
  @moduledoc "Test encoding typespecs"

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

  def test_encode_option_headers_true do
    [%{dummy: "input"}, %{dummy: "value"}] |> CSV.encode(headers: true) |> Enum.to_list()
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
