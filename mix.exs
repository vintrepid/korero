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
      description: "An Ash-native task and job queue built on Oban",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        files: ~w(lib docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md SECURITY.md)
      ],
      docs: [
        main: "readme",
        source_url: @source_url,
        extras: ["README.md", "docs/integration.md", "CHANGELOG.md", "SECURITY.md"]
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:ash, "~> 3.33"},
      {:ash_state_machine, "~> 0.2.13"},
      {:oban, "~> 2.23"},
      {:ash_oban, "~> 0.8.14"},
      # Security floor for an existing transitive dependency; see SECURITY.md.
      {:decimal, ">= 3.0.0 and < 4.0.0"},
      {:sourceror, "~> 1.12", only: [:dev, :test], runtime: false},
      {:simple_sat, "~> 0.1 and >= 0.1.1", only: :test},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_environment), do: ["lib"]
end
