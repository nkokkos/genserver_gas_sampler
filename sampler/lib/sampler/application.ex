defmodule Sampler.Application do
  @moduledoc """
  OTP Application for the Sampler Nerves firmware.

  This application coordinates the startup of:
  - GasSensor OTP app (automatically started as dependency)
    - GasSensor.ReadingAgent - Stores latest reading
    - GasSensor.Sensor - Performs I2C readings
  - GasSensorWeb OTP app (automatically started as dependency)
    - Phoenix web interface on port 80

  ## Startup Order

  1. GasSensor starts (as a dependency)
     - ReadingAgent starts first
     - Sensor starts second and updates Agent after each reading
  2. GasSensorWeb starts (as a dependency)
     - Web server starts and reads from Agent
     - No direct I2C access from web layer

  This ensures no I2C contention - only the Sensor GenServer touches the I2C bus.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # OTP applications (gas_sensor and gas_sensor_web) are automatically started
    # as dependencies defined in mix.exs. No manual children needed here.
   
    # Just copy pasting from the blinky example:
    # https://github.com/nerves-project/nerves_examples/blob/main/blinky/lib/blinky/application.ex
    delux_options = Application.get_all_env(:sampler)
    Logger.debug("Blinky: target-specific options for Delux: #{inspect(delux_options)}")

    children = [
      # See https://hexdocs.pm/delux
      {Delux, delux_options ++ [initial: Delux.Effects.blink(:on, 2)]}
    ]
    
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sampler.Supervisor]
    Supervisor.start_link(children, opts)
  end





end
