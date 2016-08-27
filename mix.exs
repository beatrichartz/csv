defmodule CSV.Mixfile do
  use Mix.Project

  def project do
    [
        app: :csv,
        version: "1.4.3",
        elixir: "~> 1.1",
        deps: deps,
        package: package,
        docs: &docs/0,
        name: "CSV",
        consolidate_protocols: true,
        source_url: "https://github.com/beatrichartz/csv",
        description: "CSV Decoding and Encoding for Elixir",
        test_coverage: [tool: ExCoveralls],
        preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test]
    ]
  end

  defp package do
    [
        maintainers: ["Beat Richartz"],
        licenses: ["MIT"],
        links: %{github: "https://github.com/beatrichartz/csv" }
    ]
  end

  defp deps do
    [
      {:parallel_stream, "~> 1.0.4"},
      {:excoveralls, "~> 0.5", only: :test},
      {:benchfella, only: :bench},
      {:ex_csv, only: :bench},
      {:csvlixir, only: :bench},
      {:cesso, only: :bench},
      {:ex_doc, "0.9.0", only: :docs},
      {:inch_ex, only: :docs},
      {:earmark, "0.1.19", only: :docs}
    ]
  end

  defp docs do
    {ref, 0} = System.cmd("git", ["rev-parse", "--verify", "--quiet", "HEAD"])

    [
        source_ref: ref,
        main: "overview"
    ]
  end
end
