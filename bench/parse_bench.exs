defmodule ParseBench do
  use Benchfella

  setup_all do
    NimbleCSV.define(MyParser, separator: separator, escape: "\"")

    if System.get_env("CSV_BENCH_OBSERVER") do
      :observer.start()
    end

    {:ok, nil}
  end

  bench "nimble_csv" do
    path
    |> File.stream!(read_ahead: 100_000)
    |> MyParser.parse_stream()
    |> Stream.run()
  end

  bench "csv" do
    path
    |> File.stream!([read_ahead: 100_000], 2000)
    |> CSV.decode!(separator: String.to_charlist(separator) |> List.first())
    |> Stream.run()
  end

  def separator do
    System.get_env("CSV_BENCH_SEPARATOR") || "\t"
  end

  def path do
    case System.get_env("CSV_BENCH_FILE_PATH") do
      nil ->
        Path.expand("./files/benchfile.csv", __DIR__)

      p ->
        p
    end
  end
end
