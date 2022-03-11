defmodule CSV.Mixfile do
  use Mix.Project

  @source_url "https://github.com/beatrichartz/csv"

  def project do
    [
      app: :csv,
      version: "2.4.1",
      elixir: "~> 1.1",
      deps: deps(),
      package: package(),
      docs: &docs/0,
      name: "CSV",
      consolidate_protocols: true,
      source_url: @source_url,
      description: "CSV Decoding and Encoding for Elixir",
      elixirc_paths: elixirc_paths(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test]
    ]
  end

  defp elixirc_paths do
    if Mix.env() == :test do
      ["lib", "test/support"]
    else
      ["lib"]
    end
  end

  def application do
    [applications: [:parallel_stream]]
  end

  defp package do
    [
      maintainers: ["Beat Richartz"],
      licenses: ["MIT"],
      links: %{GitGub: @source_url}
    ]
  end

  defp deps do
    [
      {:parallel_stream, "~> 1.0.4 or ~> 1.1.0"},
      {:excoveralls, "~> 0.13", only: :test},
      {:benchfella, ">= 0.0.0", only: :bench},
      {:ex_csv, ">= 0.0.0", only: :bench},
      {:csvlixir, ">= 0.0.0", only: :bench},
      {:cesso, ">= 0.0.0", only: :bench},
      {:ex_doc, ">= 0.0.0", only: :docs},
      {:inch_ex, "~> 0.5", only: :docs},
      {:earmark, "~> 1.2", only: :docs}
    ]
  end

  defp docs do
    {ref, 0} = System.cmd("git", ["rev-parse", "--verify", "--quiet", "HEAD"])

    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_ref: ref
    ]
  end
end
