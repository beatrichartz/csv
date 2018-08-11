defmodule TestSupport.StreamHelpers do
  def to_stream(list) when is_list(list) do
    list |> Stream.map(& &1)
  end
end
