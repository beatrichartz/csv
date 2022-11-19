defmodule TestSupport.StreamHelpers do
  @moduledoc "Helpers for creating streams in tests"

  def to_stream(list) when is_list(list) do
    list |> Stream.map(& &1)
  end

  def to_line_stream(list) when is_list(list) do
    list |> Stream.map(fn s -> s <> "\n" end)
  end

  def to_byte_stream(binary, chunk_size) do
    to_byte_stream(binary, chunk_size, [])
  end

  defp to_byte_stream(binary, chunk_size, accumulator) when byte_size(binary) <= chunk_size do
    accumulator ++ [binary]
  end

  defp to_byte_stream(binary, chunk_size, accumulator) do
    <<chunk::size(chunk_size)-binary, rest::binary>> = binary
    to_byte_stream(rest, chunk_size, accumulator ++ [<<chunk::size(chunk_size)-binary>>])
  end
end
