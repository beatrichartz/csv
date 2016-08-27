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
    multiline_escape_max_lines = options |> Keyword.get(:multiline_escape_max_lines, @multiline_escape_max_lines)

    stream |> Stream.transform(fn -> { [], 0 } end, fn line, { collected, collected_size } ->
      case collected do
        [] -> start_aggregate(line, separator)
        _ when collected_size < multiline_escape_max_lines ->
          continue_aggregate(collected, collected_size + 1, line, separator)
        _ -> raise CorruptStreamError,
                   message: "Stream halted with escape sequence spanning more than #{multiline_escape_max_lines} lines. Use the multiline_escape_max_lines option to increase this threshold."
      end
    end, fn { collected, _ } ->
      case collected do
        [] -> :ok
        _ -> raise CorruptStreamError,
                   message: "Stream halted with unterminated escape sequence"
      end
    end)
  end
  defp start_aggregate(line, separator) do
    cond do
      is_open?(line, separator) ->
        { [], { [line], 1 } }
      true ->
        { [line], { [], 0 } }
    end
  end
  defp continue_aggregate(collected, collected_size, line, separator) do
    { is_closing, tail } = is_closing?(line, separator)
    cond do
      is_closing && is_open?(tail, separator) ->
        { [], { collected ++ [line], collected_size } }
      is_closing ->
        { [collected ++ [line] |> Enum.join(@delimiter)], { [], collected_size } }
      true ->
        { [], { collected ++ [line], collected_size } }
    end
  end

  defp is_closing?(line, separator) do
    is_closing?(line, "", true, separator)
  end

  defp is_closing?(<< @double_quote :: utf8 >> <> tail, _, quoted, separator) do
    is_closing?(tail, << @double_quote :: utf8 >>, !quoted, separator)
  end
  defp is_closing?(<< head :: utf8 >> <> tail, _, quoted, separator) do
    is_closing?(tail, << head :: utf8 >>, quoted, separator)
  end
  defp is_closing?("", _, quoted, _) do
    { !quoted, "" }
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
