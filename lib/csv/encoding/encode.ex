defprotocol CSV.Encode do
  @fallback_to_any true
  @moduledoc """
  Implement encoding for your data types.
  """

  @doc """
  The encode function to implement, gets passed the data and env as a keyword
  list containing the currently used separator and delimiter.
  """
  def encode(data, env \\ [])
end

defimpl CSV.Encode, for: Any do
  @doc """
  Default encoding implementation, uses the string protocol and feeds into the
  string encode implementation
  """

  def encode(data, env \\ []) do
    to_string(data) |> CSV.Encode.encode(env)
  end
end

defimpl CSV.Encode, for: BitString do
  use CSV.Defaults

  @doc """
  Standard string encoding implementation, escaping cells with double quotes
  where necessary.
  """

  def encode(data, env \\ []) do
    separator = env |> Keyword.get(:separator, @separator)
    delimiter = env |> Keyword.get(:delimiter, @delimiter)
    force_quotes = env |> Keyword.get(:force_quotes, @force_quotes)
    escape_formulas = env |> Keyword.get(:escape_formulas, @escape_formulas)

    data =
      if escape_formulas and String.starts_with?(data, @escape_formula_start) do
        "'" <> data
      else
        data
      end

    patterns = [
      <<separator::utf8>>,
      delimiter,
      <<@carriage_return::utf8>>,
      <<@newline::utf8>>,
      <<@double_quote::utf8>>
    ]

    patterns =
      if escape_formulas do
        patterns ++ @escape_formula_start
      else
        patterns
      end

    cond do
      force_quotes || String.contains?(data, patterns) ->
        <<@double_quote::utf8>> <>
          (data
           |> String.replace(
             <<@double_quote::utf8>>,
             <<@double_quote::utf8>> <> <<@double_quote::utf8>>
           )) <> <<@double_quote::utf8>>

      true ->
        data
    end
  end
end
