defmodule Firmware.MixProject do
  use Mix.Project

  @app :firmware
  @version "0.2.5"

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

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  defp deps do
    [
      # Core Nerves dependencies
      {:nerves,       "~> 1.13", runtime: false},
      {:shoehorn,     "~> 0.9.1" },
      {:ring_logger,  "~> 0.11.0"},
      {:toolshed,     "~> 0.4.0" },
      
      # Allow Nerves.Runtime on host to support development, testing and CI
      {:nerves_runtime, "~> 0.13.12"},

      # Nerves Pack for networking
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},
       
      # Dependencies for specific targets
      # NOTE: It's generally low risk and recommended to follow minor version
      # bumps to Nerves systems. Since these include Linux kernel and Erlang
      # version updates, please review their release notes in case
      # changes to your application are needed.
      {:nerves_system_bbb, "~> 2.19", runtime: false, targets: :bbb},
      {:nerves_system_grisp2, "~> 0.8", runtime: false, targets: :grisp2},
      {:nerves_system_osd32mp1, "~> 0.15", runtime: false, targets: :osd32mp1},
      {:nerves_system_mangopi_mq_pro, "~> 0.6", runtime: false, targets: :mangopi_mq_pro},
      {:nerves_system_qemu_aarch64, "~> 0.1", runtime: false, targets: :qemu_aarch64},
      {:nerves_system_rpi, "~> 2.0", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 2.0", runtime: false, targets: :rpi0},
      {:nerves_system_rpi0_2, "~> 2.0", runtime: false, targets: :rpi0_2},
      {:nerves_system_rpi2, "~> 2.0", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 2.0", runtime: false, targets: :rpi3},
      {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5, "~> 2.0", runtime: false, targets: :rpi5},
      {:nerves_system_x86_64, "~> 1.24", runtime: false, targets: :x86_64},


      # Enable networking, direct, gadget mode and net wizard to connect to wifi router
      # Notice, that this will be included for the targets, so if you are testing on 
      # host, this iex -S mix won't break.

      {:vintage_net,        "~> 0.13", targets: @all_targets },
      {:vintage_net_wifi,   "~> 0.12", targets: @all_targets },    
      {:vintage_net_direct, "~> 0.10.7", targets: @all_targets },
     
      # Enable Vintage Net Wizard.  
      {:vintage_net_wizard, "~> 0.4", targets: @all_targets},

      # NervesTime keeps the system clock on Nerves devices in sync 
      # when connected to the network and close to in sync when disconnected.
      {:nerves_time, "~> 0.4.2" },

      # NervesTimeZones provides a way of managing local time on embedded devices.  
      {:nerves_time_zones, "~> 0.3.2" },

      # add blinky dependency so it always flashes while the app is up
      # https://github.com/nerves-project/nerves_examples/tree/main/blinky
      # Look into the application.ex to see how it is used
      {:delux, "~> 0.4.1", targets: @all_targets},
      
      # Use the json parser 
      {:jason, "~> 1.4"},
      
      # This is used for the button in VintageNetWizard
      {:circuits_gpio,  "~> 2.0"}, # for the button wifi wizard

      # Use Bosch barometric pressure sensors in Elixir 
      # Use this library maintained by Frank Hunleth:
      # https://github.com/elixir-sensors/bmp280
      # This is included in the mix file of the otp app:
      # gas_sensor. It is included here as reference.
      #{:bmp280, "~> 0.2" },

      # Poncho dependencies
      # See https://embedded-elixir.com/post/2017-05-19-poncho-projects
      # This OTP app contains all the business logic of communicating
      # with the boards and getting the data out.
      # Including this otp this way, it forces the supervisor to start 
      # the app as dependency.

      # start the business logic and signal sampler: 
      {:gas_sensor, path: "../gas_sensor", env: Mix.env()},
      # start the web page 
      {:gas_sensor_web, path: "../gas_sensor_web", env: Mix.env()},

      # runtime defaults to true:
      # {:gas_sensor_web, path: "../gas_sensor_web", targets: @all_targets, env: Mix.env()}
      # {:gas_sensor_web, path: "../gas_sensor_web", targets: @all_targets},
      # {:gas_sensor_web, path: "../gas_sensor_web", runtime: false, targets: @all_targets},
    
    ]
  end

  def release do
    [

      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      
      # Note about vm.args.eex:
      # vm.args.eex is automatically picked up - no config needed
      # you don't have to include the following line, it will break, anyway.
      # we searched and included an optimized vm file since we will be doing
      # sampling, sending data and phoenix live view. 
      # rel/vm.args.eex contains VM optimizations for Pi Zero W
 
      # Fixed cookie for demonstration and remote access via Livebook
      # In production, use a secure random cookie via env var: System.get_env("ERL_COOKIE")
      cookie: "tgs5042_demo_2026",
      
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod

    ]
  end

  # Uncomment the following line if using Phoenix > 1.8.
  defp listeners(:host, :dev), do: [Phoenix.CodeReloader]
  defp listeners(_, _), do: []

end
