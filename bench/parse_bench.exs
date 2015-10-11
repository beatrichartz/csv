defmodule ParseBench do
  use Benchfella

  setup_all do
    if System.get_env("OBSERVER") do
      :observer.start()
    end

    { :ok, nil }
  end

  bench "cesso" do
    path
    |> File.stream!
    |> Cesso.decode(separator: "\t")
    |> Stream.run
  end

  bench "csv" do
    path
    |> File.stream!
    |> CSV.decode(separator: ?\t)
    |> Stream.run
  end

  bench "ex_csv" do
    path
    |> File.read!
    |> ExCsv.parse!(delimiter: '\t')
    |> Stream.run
  end

  def path do
    Path.expand("./files/articles.csv", __DIR__) 
  end
end
