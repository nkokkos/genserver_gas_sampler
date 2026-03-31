defmodule Sampler.MixProject do
  use Mix.Project

  @app :sampler
  @version "0.1.0"
  # Raspberry Pi Zero W only
  @target :rpi0

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.15",
      archives: [nerves_bootstrap: "~> 1.14"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  def application do
    [
      mod: {Sampler.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      # Core Nerves dependencies
      {:nerves, "~> 1.11", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},

      # Allow Nerves.Runtime on host to support development, testing and CI
      {:nerves_runtime, "~> 0.13.0"},

      # Nerves Pack for networking
      {:nerves_pack, "~> 0.7.0", targets: @target},

      # add blinky dependency so it always flashs while the app is up
      # https://github.com/nerves-project/nerves_examples/tree/main/blinky
      {:delux, "~> 0.4.1", targets: @targets},

      # Business logic from local poncho
      {:gas_sensor, path: "../gas_sensor", targets: @target},

      # Phoenix web interface
      {:gas_sensor_web, path: "../gas_sensor_web", targets: @target},

      # Raspberry Pi Zero system - the only target
      {:nerves_system_rpi0, "~> 1.27", runtime: false, targets: @target}
    ]
  end

  def release do
    [
      overwrite: true,
      # Fixed cookie for demonstration and remote access via Livebook
      # In production, use a secure random cookie via env var: System.get_env("ERL_COOKIE")
      cookie: "gassensor_demo_cookie_2024",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod
      # rel/vm.args.eex contains VM optimizations for Pi Zero W
    ]
  end
end
