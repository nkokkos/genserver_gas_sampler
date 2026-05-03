defmodule Firmware.Application do
  @moduledoc """
  OTP Application for the Firmware Nerves firmware.

  This application provides networking through gadget mode and
  vintage_net and starts a blinking sequence to show that 
  the app is up and working.

  It coordinates the startup of:
  - GasSensor OTP app (automatically started as dependency)
    - GasSensor.ReadingAgent - Stores latest reading
    - GasSensor.Sensor - Performs I2C readings
 
 - UI OTP app (automatically started as dependency)
    - Phoenix web interface on port 80

  ## Startup Order

  1. GasSensor starts (as a dependency)
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
   
    # Use example from blinky example:
    # https://github.com/nerves-project/nerves_examples/blob/main/blinky/lib/blinky/application.ex
     
    # This will read from config/rpi0.ex file to read the options for delux:    
    # delux_options = Application.get_all_env(:firmware)
   
    # During sampling we can present this status
    # ACT LED starts blinking fast (5Hz), covering the heartbeat
    # Delux.render(Delux.Effects.blink(:on, 5), :notification)
    # 
    
    # Clear the notification slot:
    # The ACT LED automatically reverts to the 1Hz heartbeat
    # Delux.render(nil, :notification)

    # Note, you can call: Delux.render(Delux.Effects.blink(:on, 10))
    # to change the blinking rate at any place in the core otp app
   
    #children = [
    # See https://hexdocs.pm/delux
    #  { Delux, [name: Delux] ++ delux_options ++ [initial: Delux.Effects.blink(:on, 2)] }
    #]

    # on nerves command line, use this 
    # :sys.get_state(Delux)
    # to find out more about the Delux configuration

    # This will turn the green light on - steady
    # Delux.render(%{status: Delux.Effects.on(:green)}, :notification)

    # This removes the "Solid On" notification
    # The LED will immediately start blinking again because the layer below is revealed
    # Delux.render(%{status: nil}, :notification)

    # Start blinking at 10 Hz. Before that, make sure that you have removed the solid on.
    # Delux.render(%{status: Delux.Effects.blink(:green, 10)})

    # Force the kernel to let go of the ACT LED
    # This ensures Delux has total control. This has to be done
    # because once this app loads, the blink never happens.
    File.write("/sys/class/leds/ACT/trigger", "none")  

    children = [
      # Add your other workers here (like your I2C sensor worker)
      {Delux, [
        name: Delux,
        indicators: %{status: %{green: "ACT"}},
        initial: %{status: Delux.Effects.blink(:on, 2)}
      ]}
    ]

  opts = [strategy: :one_for_one, name: Firmware.Supervisor]
  
  case Supervisor.start_link(children, opts) do
    {:ok, pid} ->
      # Force a refresh just in case the init-blink was missed
      Delux.render(%{status: Delux.Effects.blink(:on, 4)})
      {:ok, pid}

    {:error, reason} ->
      {:error, reason}
  end 


   

  end


end
