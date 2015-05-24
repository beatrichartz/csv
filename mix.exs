defmodule CSV.Mixfile do
  use Mix.Project

  def project do
    [
        app: :csv,
        version: "1.0.0",
        elixir: "~> 1.0.0 or ~> 1.1-dev",
        deps: deps,
        package: package,
        docs: &docs/0,
        name: "CSV",
        source_url: "https://github.com/beatrichartz/csv",
        description: "CSV Decoding and Encoding for Elixir"
    ]
  end

  defp package do
    [
        contributors: ["Beat Richartz"],
        licenses: ["MIT"],
        links: %{github: "https://github.com/beatrichartz/csv" }
    ]
  end

  defp deps do
    [
      {:benchfella, only: :bench},
      {:ex_csv, only: :bench},
      {:csvlixir, only: :bench},
      {:cesso, only: :bench},
      {:ex_doc, only: :docs},
      {:inch_ex, only: :docs},
      {:earmark, only: :docs}
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
