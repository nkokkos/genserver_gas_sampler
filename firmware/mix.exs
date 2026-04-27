defmodule Firmware.MixProject do
  use Mix.Project

  @app :firmware
  @version "0.1.2"

  # Include all targets
  @all_targets [
    :rpi,
    :rpi0,
    :rpi0_2,
    :rpi2,
    :rpi3,
    :rpi3a,
    :rpi4,
    :rpi5,
    :bbb,
    :osd32mp1,
    :x86_64,
    :grisp2,
    :mangopi_mq_pro
  ]


  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.16",
      archives: [nerves_bootstrap: "~> 1.14"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  def application do
    [
      mod: {Firmware.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :ssl] 
    ]
  end

  defp deps do
    [
      # Core Nerves dependencies
      {:nerves,       "~> 1.11", runtime: false},
      {:shoehorn,     "~> 0.9.1" },
      {:ring_logger,  "~> 0.11.0"},
      {:toolshed,     "~> 0.4.0" },
      
      # Allow Nerves.Runtime on host to support development, testing and CI
      {:nerves_runtime, "~> 0.13.0"},

      # Nerves Pack for networking
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},

      # Dependencies for most targets using the blinky example
      {:nerves_system_rpi,      "~> 2.0", runtime: false, targets: :rpi},
      {:nerves_system_rpi0,     "~> 2.0", runtime: false, targets: :rpi0},
      {:nerves_system_rpi0_2,   "~> 2.0", runtime: false, targets: :rpi0_2},
      {:nerves_system_rpi2,     "~> 2.0", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3,     "~> 2.0", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a,    "~> 2.0", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4,     "~> 2.0", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5,     "~> 2.0", runtime: false, targets: :rpi5},
      {:nerves_system_bbb,      "~> 2.8", runtime: false, targets: :bbb},
      {:nerves_system_osd32mp1, "~> 0.4", runtime: false, targets: :osd32mp1},
      {:nerves_system_x86_64, "~> 1.13", runtime: false, targets: :x86_64},
      {:nerves_system_grisp2, "~> 0.3", runtime: false, targets: :grisp2},
      {:nerves_system_mangopi_mq_pro, "~> 0.4", runtime: false, targets: :mangopi_mq_pro},

      # Enable networking, direct, gadget mode and net wizard to connect to wifi router
      {:vintage_net,        "~> 0.13",    targets: @all_targets},
      {:vintage_net_wifi,   "~> 0.12",    targets: @all_targets},    
      {:vintage_net_direct, "~> 0.10.7",  targets: @all_targets},
      {:vintage_net_wizard, "~> 0.4",     targets: @all_targets},

      # add blinky dependency so it always flashes while the app is up
      # https://github.com/nerves-project/nerves_examples/tree/main/blinky
      {:delux, "~> 0.4.1", targets: @all_targets},

      # We will use I2C mainly for the breakout boards
      #{:circuits_gpio,  "~> 2.0"},
      #{:circuits_i2c,   "~> 2.0"},
      #{:pinout,         "~> 0.1"},

      # Use Bosch barometric pressure sensors in Elixir 
      # Use this library maintained by Frank Hunleth:
      # https://github.com/elixir-sensors/bmp280
      #{:bmp280, "~> 0.2" },

      # Business logic from local poncho
      # This app contains all the logic needed to read the sensors and
      # push the data out
      
      # Poncho dependencies
      # See https://embedded-elixir.com/post/2017-05-19-poncho-projects
      # {:gas_sensor, path: "../gas_sensor", env: Mix.env()},

      # Phoenix web interface that sports a simple web page that displays
      # data in live view
      # {:gas_sensor_web, path: "../gas_sensor_web", targets: @targets},
    
    ]
  end

  def release do
    [

      overwrite: true,

      # Fixed cookie for demonstration and remote access via Livebook
      # In production, use a secure random cookie via env var: System.get_env("ERL_COOKIE")
      cookie: "gas_sensor_demo_cookie_2026",
      
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod

      # don't include this for the time being
      #rel/vm.args.eex contains VM optimizations for Pi Zero W
    ]
  end
end
