defmodule CSV.Parser do

  @moduledoc ~S"""
  The CSV Parser module - parses tokens coming from the lexer and sends them
  to the receiver process / the decoder.
  """

  @doc """
  Parses tokens by receiving them from a sender / lexer and sending them to
  the given receiver process (the decoder).

  ## Options

  Options get transferred from the decoder. They are:

    * `:strip_cells` – When set to true, will strip whitespace from cells. Defaults to false.
  """

  def parse_into(receiver, options \\ []) do
    strip_cells = Keyword.get(options, :strip_cells, false)

    parse([], receiver, false, false, strip_cells)
  end

  defp parse(row, receiver, quoted, _, strip_cells) when quoted do
    receive do
      {:content, content} ->
        parse(add_to_last_content(row, content), receiver, quoted, false, strip_cells)
      {:separator, content} ->
        parse(add_to_last_content(row, content), receiver, quoted, false, strip_cells)
      {:delimiter, content} ->
        parse(add_to_last_content(row, content), receiver, quoted, false, strip_cells)
      {:double_quote, _} ->
        parse(row, receiver, not quoted, true, strip_cells)
      {:end, index} ->
        send receiver, {:syntax_error, {index, "Unterminated escape sequence." }}
      {:halt, index} ->
        send receiver, {:syntax_error, {index, "Stream halted with unterminated escape sequence." }}
      {:stream_error, content } ->
        send receiver, {:stream_error, content }
    end
  end

  defp parse(row, receiver, quoted, after_unquote, strip_cells) when not quoted do
    receive do
      {:content, content} ->
        parse(add_to_last_content(row, content), receiver, quoted, false, strip_cells)
      {:separator, _} ->
        parse(add_content(row, "", strip_cells), receiver, quoted, false, strip_cells)
      {:delimiter, _} ->
        parse(row, receiver, quoted, false, strip_cells)
      {:start, _} ->
        parse([""], receiver, quoted, false, strip_cells)
      {:double_quote, content} when after_unquote ->
        parse(add_to_last_content(row, content), receiver, true, false, strip_cells)
      {:double_quote, content} ->
        cond do
          last_content_length(row) == 0 ->
            parse(row, receiver, not quoted, false, strip_cells)
          true ->
            parse(add_to_last_content(row, content), receiver, quoted, false, strip_cells)
        end
      {:end, index } ->
        send receiver, {:row, {index, strip_last_cell(row, strip_cells)}}
        parse([], receiver, false, false, strip_cells)
      {:halt, index } ->
        send receiver, {:halt, index}
      {:stream_error, content } ->
        send receiver, {:stream_error, content }
      {:lexer_error, content } ->
        send receiver, {:lexer_error, content }
    end
  end


  defp add_to_last_content(row, content) do
    List.update_at(row, length(row) - 1, &(&1 <> content))
  end

  defp add_content(row, content, strip_cells) do
    strip_last_cell(row, strip_cells) ++ [content]
  end

  defp last_content_length(row) do
    Enum.fetch!(row, length(row) - 1) |> String.length
  end

  defp strip_last_cell(row, strip_cells) do
    cond do
      strip_cells ->
        List.update_at(row, length(row) - 1, &(String.strip(&1)))
      true ->
        row
    end
  end

end
