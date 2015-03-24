defmodule CSV.Mixfile do
  use Mix.Project

  def project do
    [
        app: :csv,
        version: "0.1.0",
        elixir: "~> 1.0",
        package: package,
        description: "CSV library"
    ]
  end

  defp package do
    [
        contributors: ["Beat Richartz"],
        licenses: ["MIT"],
        links: [ %{ "GitHub" => "https://github.com/beatrichartz/csv" } ]
    ]
  end
end
