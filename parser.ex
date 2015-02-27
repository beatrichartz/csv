defmodule CSV.Parser do
  def parse(source, options \\ [])

  def parse(string, options) when string |> is_binary do
    parse(lines(string), options)
  end

  def parse(lines, options) do
    separator = options[:separator] || ","

    Stream.map unescape(lines), fn line ->
      columns(line, separator)
    end
  end

  defp lines(string) do
    Stream.unfold string, fn string ->
      case string |> String.split(["\r\n", "\n"], parts: 2) do
        [""]         -> nil
        [elem, rest] -> { elem, rest }
        [elem]       -> { elem, "" }
      end
    end
  end

  defp unescape(lines) do
    Stream.transform lines, { [], false }, fn line, { current, inside } ->
      current = [line | current]

      if closed?(line, inside) do
        { [current |> Enum.reverse |> Enum.join("\n")], { [], false } }
      else
        { [], { current, true } }
      end
    end
  end

  defp closed?(<< ?" :: utf8, rest :: binary >>, inside) do
    closed?(rest, not inside)
  end

  defp closed?(<< _ :: utf8, rest :: binary >>, inside) do
    closed?(rest, inside)
  end

  defp closed?("", inside) do
    not inside
  end

  defp columns(line, separator) do
    columns([], false, 0, line, line, separator) |> Enum.reverse |> Enum.map fn
      << ?" :: utf8, rest :: binary >> ->
        String.slice(rest, 0 .. -2) |> String.replace ~S<"">, ~S<">

      column ->
        column
    end
  end

  defp columns(columns, _, offset, "", line, _) do
    [String.slice(line, 0 .. offset) | columns]
  end

  defp columns(columns, inside, offset, << ?" :: utf8, rest :: binary >>, line, separator) do
    columns(columns, not inside, offset + 1, rest, line, separator)
  end

  defp columns(columns, inside, offset, rest, line, separator) do
    if not inside and rest |> String.starts_with? separator do
      columns = [String.slice(line, 0 .. offset - 1) | columns]
      line    = String.slice(line, offset + String.length(separator) .. -1)

      columns(columns, inside, 0, line, line, separator)
    else
      << _ :: utf8, rest :: binary >> = rest

      columns(columns, inside, offset + 1, rest, line, separator)
    end
  end
end
