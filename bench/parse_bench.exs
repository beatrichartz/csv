defmodule ParseBench do
  use Benchfella

  setup_all do
    if System.get_env("CSV_BENCH_OBSERVER") do
      :observer.start()
    end

    { :ok, nil }
  end

  bench "cesso" do
    path
    |> File.stream!
    |> Cesso.decode(separator: separator)
    |> Stream.run
  end

  bench "csv" do
    sep = case separator do
      "\\t" -> ?\t
      <<s::utf8>> -> s
    end

    path
    |> File.stream!
    |> CSV.decode(separator: sep)
    |> Stream.run
  end

  bench "csv no multiline" do
    sep = case separator do
      "\\t" -> ?\t
      <<s::utf8>> -> s
    end

    path
    |> File.stream!
    |> CSV.decode(separator: sep, multiline_escape: false)
    |> Stream.run
  end

  bench "ex_csv" do
    path
    |> File.read!
    |> ExCsv.parse!(delimiter: String.to_char_list(separator))
    |> Stream.run
  end

  def separator do
    System.get_env("CSV_BENCH_SEPARATOR") || ","
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
