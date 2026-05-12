defmodule GasSensorWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :gas_sensor_web,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {GasSensorWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix and LiveView - optimized for embedded
      {:phoenix, "~> 1.8.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      {:req, "~> 0.5"},

      # Telemetry (lightweight metrics)
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},

      # Web server - Bandit is lighter than Cowboy for embedded
      {:bandit, "~> 1.0"},

      # JSON parsing
      {:jason, "~> 1.4"},

      # Internationalization
      {:gettext, "~> 0.20"},

      # Business logic from local poncho, 
      # This line must be removed when you compile firmware
      # this only exists, if you need to have access to methods
      # in gas_sensor from this ui app.
      # {:gas_sensor, path: "../gas_sensor", runtime: true},
      
      # Only for development
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},

    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind gas_sensor_web", "esbuild gas_sensor_web"],
      "assets.deploy": [
        "tailwind gas_sensor_web --minify",
        "esbuild gas_sensor_web --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end


end
