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
      consolidate_protocols: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: [
        precommit: [
          "hex.audit",
          "compile --warnings-as-errors",
          "format --check-formatted",
          "docs",
          "test --warnings-as-errors"
        ]
      ],
      deps: deps(),
      description: "An embeddable communication and task workspace built on Ash and Oban",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        files: ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md SECURITY.md)
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

  def cli, do: [preferred_envs: [precommit: :test]]

  defp deps do
    [
      {:ash, "~> 3.34 and >= 3.34.6"},
      {:ash_state_machine, "~> 0.2.13"},
      {:oban, "~> 2.23"},
      {:ash_oban, "~> 0.8.14"},
      {:tag_ash, github: "vintrepid/tag_ash", ref: "a525fc456e4b0828f08fc61c956c439378ccc2aa"},
      {:phoenix_live_view, "~> 1.2 and >= 1.2.11"},
      {:phoenix_html, "~> 4.3"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.8.4", optional: true},
      {:lazy_html, ">= 0.0.0", only: :test},
      # Security floor for an existing transitive dependency; see SECURITY.md.
      {:decimal, "~> 3.1.2"},
      {:sourceror, "~> 1.12"},
      {:simple_sat, "~> 0.1 and >= 0.1.1", only: :test},
      {:ex_doc, "~> 0.38", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_environment), do: ["lib"]
end
