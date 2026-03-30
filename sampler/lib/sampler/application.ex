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

  @impl true
  def start(_type, _args) do
    # OTP applications (gas_sensor and gas_sensor_web) are automatically started
    # as dependencies defined in mix.exs. No manual children needed here.

    # We can add target-specific workers here if needed in the future
    children = target_children()

    opts = [strategy: :one_for_one, name: Sampler.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp target_children do
    if Mix.target() == :host do
      # Host environment - applications are started by mix, 
      # but we verify the web endpoint is accessible
      [
        # Empty - OTP apps handle everything
      ]
    else
      # Target environment - OTP apps start automatically
      # I2C bus configuration is in config/target.exs
      [
        # Empty - OTP apps (gas_sensor and gas_sensor_web) 
        # start automatically and handle everything
      ]
    end
  end
end
