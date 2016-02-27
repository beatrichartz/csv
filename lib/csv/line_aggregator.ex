defmodule CSV.LineAggregator do
  use CSV.Defaults

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
    stream |> Stream.transform([], fn line, collected ->
      case collected do
        [] ->
          cond do
            is_open?(line, separator) ->
              { [], [line] }
            true ->
              { [line], [] }
          end
        _ ->
          cond do
            is_closing?(line, separator) ->
              { [collected ++ [line] |> Enum.join(@delimiter)], [] }
            true ->
              { [], collected ++ [line] }
          end
      end
    end)
  end

  defp is_closing?(line, separator) do
    is_closing?(line, "", true, separator)
  end

  defp is_closing?(<< head :: utf8 >> <> tail, << @double_quote :: utf8 >>, quoted, separator) do
    case head do
      @double_quote -> is_closing?(tail, @double_quote, !quoted, separator)
      _ -> is_closing?(tail, @double_quote, quoted, separator)
    end
  end
  defp is_closing?(<< head :: utf8 >> <> tail, _, quoted, separator) do
    is_closing?(tail, << head :: utf8 >>, quoted, separator)
  end
  defp is_closing?("", << @double_quote :: utf8 >>, _, _) do
    true
  end
  defp is_closing?("", _, _, _) do
    false
  end

  defp is_open?(line, separator) do
    is_open?(line, "", false, separator)
  end

  defp is_open?(<< @double_quote :: utf8 >> <> tail, << @double_quote :: utf8 >>, quoted, separator) do
    is_open?(tail, @double_quote, quoted, separator)
  end
  defp is_open?(<< @double_quote :: utf8 >> <> tail, last_token, false, separator) do
    case last_token do
      << ^separator :: utf8 >> ->
        is_open?(tail, @double_quote, true, separator)
      _ ->
        is_open?(tail, @double_quote, false, separator)
    end
  end
  defp is_open?(<< head :: utf8 >> <> tail, _, quoted, separator) do
    is_open?(tail, << head :: utf8 >>, quoted, separator)
  end
  defp is_open?(<< head >> <> tail, _, quoted, separator) do
    is_open?(tail, << head >>, quoted, separator)
  end
  defp is_open?("", << @double_quote :: utf8 >>, quoted, _) do
    !quoted
  end
  defp is_open?("", _, quoted, _) do
    quoted
  end


end
