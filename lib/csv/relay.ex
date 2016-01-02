defmodule CSV.Relay do
  def listen(receiver) do
    receive do
      :next ->
        receive do
          row ->
            send receiver, { self, row }
            receiver |> listen
        end
      :halt -> :halt
    end
  end
end
