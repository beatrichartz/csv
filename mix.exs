defmodule CSV.Mixfile do
  use Mix.Project

  @source_url "https://github.com/beatrichartz/csv"

  def project do
    [
      app: :csv,
      version: "3.0.5",
      elixir: "~> 1.5",
      deps: deps(),
      package: package(),
      docs: &docs/0,
      name: "CSV",
      consolidate_protocols: true,
      source_url: @source_url,
      description: "CSV Decoding and Encoding for Elixir",
      elixirc_paths: elixirc_paths(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test],
      dialyzer: [
        plt_add_apps: [:mnesia],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:unmatched_returns, :error_handling, :no_opaque, :underspecs],
        paths: ["_build/test/lib/csv/ebin"]
      ]
    ]
  end

  defp elixirc_paths do
    if Mix.env() == :test do
      ["lib", "test/support", "test/dialyzer"]
    else
      ["lib"]
    end
  end

  defp package do
    [
      maintainers: ["Beat Richartz"],
      licenses: ["MIT"],
      links: %{GitHub: @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: :test},
      {:benchfella, ">= 0.0.0", only: :bench},
      {:eflame, "~> 1.0", only: :bench},
      {:nimble_csv, ">= 0.0.0", only: :bench},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false},
      {:inch_ex, "~> 0.5", only: :docs},
      {:earmark, "~> 1.4", only: :docs}
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
