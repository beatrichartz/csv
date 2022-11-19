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

  @type encode_options ::
          {:separator, char()}
          | {:escape_character, char()}
          | {:delimiter, String.t()}
          | {:force_escaping, boolean()}
          | {:escape_formulas, boolean()}

  @spec encode(bitstring(), [encode_options()]) :: bitstring()
  def encode(data, env \\ []) do
    separator = <<env |> Keyword.get(:separator, @separator)::utf8>>
    escape = <<env |> Keyword.get(:escape_character, @escape_character)::utf8>>
    delimiter = env |> Keyword.get(:delimiter, @carriage_return <> @newline)
    force_escaping = env |> Keyword.get(:force_escaping, @force_escaping)
    escape_formulas = env |> Keyword.get(:escape_formulas, @escape_formulas)

    data =
      if escape_formulas and String.starts_with?(data, @escape_formula_start) do
        "'" <> data
      else
        data
      end

    patterns = [
      separator,
      delimiter,
      @carriage_return,
      @newline,
      escape
    ]

    patterns =
      if escape_formulas do
        patterns ++ @escape_formula_start
      else
        patterns
      end

    if force_escaping || String.contains?(data, patterns) do
      escape <>
        (data
         |> String.replace(
           escape,
           escape <> escape
         )) <> escape
    else
      data
    end
  end
end
