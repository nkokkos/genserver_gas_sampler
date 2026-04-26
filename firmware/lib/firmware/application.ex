defmodule Firmware.Application do
  @moduledoc """
  OTP Application for the Firmware Nerves firmware.

  This application provides networking through gadget mode and
  vintage_net and starts a blinking sequence to show that 
  the app is up and working.

  It coordinates the startup of:
  - Core OTP app (automatically started as dependency)
    - Core.ReadingAgent - Stores latest reading
    - Core.Sensor - Performs I2C readings
  - UI OTP app (automatically started as dependency)
    - Phoenix web interface on port 80

  ## Startup Order

  1. Core starts (as a dependency)
     - ReadingAgent starts first
     - Sensor starts second and updates Agent after each reading
  2. UI starts (as a dependency)
     - Web server starts and reads from Agent
     - No direct I2C access from web layer

  This ensures no I2C contention - only the Sensor GenServer touches the I2C bus.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do

    # OTP applications (core and ui) are automatically started
    # as dependencies defined in mix.exs. No manual children needed here.
   
    # Just copy pasting from the blinky example:
    # https://github.com/nerves-project/nerves_examples/blob/main/blinky/lib/blinky/application.ex
    
    # This will read from config/rpi0.ex file to read the options for delux:    
    delux_options = Application.get_all_env(:firmware)
    
    Logger.debug("Blinky: target-specific options for Delux: #{inspect(delux_options)}")

    # Note, you can call: Delux.render(Delux.Effects.blink(:on, 10))
    # to change the blinking rate at any place in the core otp app
   
    children = [
      # See https://hexdocs.pm/delux
      { Delux, [name: Delux] ++ delux_options ++ [initial: Delux.Effects.blink(:on, 2)] }
    ]
 
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Firmware.Supervisor]
    Supervisor.start_link(children, opts)
  end


end
