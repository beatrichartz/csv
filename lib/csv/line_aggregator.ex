defmodule CSV.LineAggregator do
  use CSV.Defaults

  alias CSV.LineAggregator.CorruptStreamError

  @moduledoc ~S"""
  The CSV LineAggregator module - aggregates lines in a stream that are part
  of a common escape sequence.
  """

  @doc """
  Aggregates the common escape sequences of a stream with the given separator.

  ## Options

  Options get transferred from the decoder. They are:

    * `:separator` – The field separator
  """

  def aggregate(stream, options \\ []) do
    separator = options |> Keyword.get(:separator, @separator)
    stream |> Stream.transform(fn -> [] end, fn line, collected ->
      case collected do
        [] -> start_aggregate(line, separator)
        _ -> continue_aggregate(collected, line, separator)
      end
    end, fn collected ->
      case collected do
        [] -> :ok
        _ -> raise CorruptStreamError, message: "Stream halted with unterminated escape sequence"
      end
    end)
  end
  defp start_aggregate(line, separator) do
    cond do
      is_open?(line, separator) ->
        { [], [line] }
      true ->
        { [line], [] }
    end
  end
  defp continue_aggregate(collected, line, separator) do
    { is_closing, tail } = is_closing?(line, separator)
    cond do
      is_closing && is_open?(tail, separator) ->
        { [], collected ++ [line] }
      is_closing ->
        { [collected ++ [line] |> Enum.join(@delimiter)], [] }
      true ->
        { [], collected ++ [line] }
    end
  end

  defp is_closing?(line, separator) do
    is_closing?(line, "", true, separator)
  end

  defp is_closing?(<< @double_quote :: utf8 >> <> tail, << @double_quote :: utf8 >>, quoted, separator) do
    is_closing?(tail, @double_quote, !quoted, separator)
  end
  defp is_closing?(<< _ :: utf8 >> <> tail, << @double_quote :: utf8 >>, quoted, _) do
    { quoted, tail }
  end
  defp is_closing?(<< head :: utf8 >> <> tail, _, quoted, separator) do
    is_closing?(tail, << head :: utf8 >>, quoted, separator)
  end
  defp is_closing?("", << @double_quote :: utf8 >>, _, _) do
    { true, "" }
  end
  defp is_closing?("", _, _, _) do
    { false, "" }
  end

  defp is_open?(line, separator) do
    is_open?(line, "", false, separator)
  end

  defp is_open?(<< @double_quote :: utf8 >> <> tail, last_token, false, separator) when last_token == << separator :: utf8 >> do
    is_open?(tail, @double_quote, true, separator)
  end
  defp is_open?(<< @double_quote :: utf8 >> <> tail, "", false, separator) do
    is_open?(tail, @double_quote, true, separator)
  end
  defp is_open?(<< @double_quote :: utf8 >> <> tail, _, quoted, separator) do
    is_open?(tail, @double_quote, !quoted, separator)
  end
  defp is_open?(<< head :: utf8 >> <> tail, _, quoted, separator) do
    is_open?(tail, << head :: utf8 >>, quoted, separator)
  end
  defp is_open?(<< head >> <> tail, _, quoted, separator) do
    is_open?(tail, << head >>, quoted, separator)
  end
  defp is_open?("", _, quoted, _) do
    quoted
  end


end
