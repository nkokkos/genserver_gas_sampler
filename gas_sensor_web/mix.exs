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
      deps: deps()
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
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},

      # Telemetry (lightweight metrics)
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # Web server - Bandit is lighter than Cowboy for embedded
      {:bandit, "~> 1.0"},

      # JSON parsing
      {:jason, "~> 1.4"},

      # Internationalization
      {:gettext, "~> 0.20"},

      # Business logic from local poncho
      {:gas_sensor, path: "../gas_sensor"},

      # Only for development
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
