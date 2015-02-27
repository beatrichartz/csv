defmodule CSV do
  def decode(source, options \\ []) do
    rows = Parser.parse(source, options)

    if options[:strip] do
      rows = rows |> Stream.map &Enum.map(&1, &String.strip/1)
    end

    case options[:columns] do
      true ->
        names = rows |> Enum.at(0)
        rows  = rows |> Stream.drop(1)

      names ->
        names = names
    end

    rows = rows |> Stream.map &Enum.zip(names, &1) |> Enum.into %{}

    if as = options[:as] do
      rows = rows |> Stream.map fn columns ->
        if options[:columns] do
          as.new(columns)
        else
          [as | columns] |> List.to_tuple
        end
      end
    end

    rows
  end
end
