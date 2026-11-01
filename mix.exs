defmodule Korero.MixProject do
  use Mix.Project

  @version "0.1.0-alpha.2"
  @source_url "https://github.com/vintrepid/korero"

  def project do
    [
      app: :korero,
      version: @version,
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      hex: [ignore_advisories: ["EEF-CVE-2026-32686"]],
      description: "An embeddable communication and task workspace built on Ash and Oban",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        files: ~w(lib docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md SECURITY.md)
      ],
      docs: [
        main: "readme",
        source_url: @source_url,
        extras: [
          "README.md",
          "docs/integration.md",
          "docs/product-architecture.md",
          "CHANGELOG.md",
          "SECURITY.md"
        ]
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:ash, "~> 3.37 and >= 3.37.2"},
      {:ash_state_machine, "~> 0.3.0"},
      {:oban, "~> 2.24 and >= 2.24.2"},
      {:ash_oban, "~> 0.10.3"},
      # Security floor for an existing transitive dependency; see SECURITY.md.
      {:decimal, ">= 3.0.0 and < 4.0.0"},
      {:sourceror, "~> 1.13", only: [:dev, :test], runtime: false},
      {:simple_sat, "~> 0.1.4", only: :test},
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_environment), do: ["lib"]
end
