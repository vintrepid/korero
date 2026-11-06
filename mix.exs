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
      {:tag_ash, github: "vintrepid/tag_ash", ref: "d5ec832df30a82cd7a16e18ce7fa9007aa4adf1f"},
      {:phoenix_live_view, "~> 1.2 and >= 1.2.13"},
      {:phoenix_html, "~> 4.4"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.8.5", optional: true},
      {:lazy_html, ">= 0.0.0", only: :test},
      {:ash, ">= 3.37.2"},
      {:ash_state_machine, ">= 0.3.0"},
      {:oban, ">= 2.24.2"},
      {:ash_oban, ">= 0.10.3"},
      # Security floor for an existing transitive dependency; see SECURITY.md.
      {:decimal, ">= 3.0.0"},
      {:sourceror, ">= 1.13.0"},
      {:simple_sat, ">= 0.1.4", only: :test},
      {:ex_doc, ">= 0.40.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_environment), do: ["lib"]
end
