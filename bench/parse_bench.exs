defmodule ParseBench do
  use Benchfella

  bench "cesso" do
    path |> File.stream! |> Cesso.decode(separator: "\t") |> Enum.count
  end

  bench "csv unordered" do
    path |> File.stream! |> CSV.decode(separator: "\t") |> Enum.count
  end

  bench "csv ordered" do
    path |> File.stream! |> CSV.decode(
      separator: "\t",
      num_pipes: 1
    ) |> Enum.count
  end

  bench "ex_csv" do
    path |> File.read! |> ExCsv.parse!(delimiter: '\t')
  end

  def path do
    Path.expand("./files/articles.csv", __DIR__) 
  end
end
