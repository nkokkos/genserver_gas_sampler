defmodule GasSensor.BME680.Stub do
  @moduledoc """
    Provides stub data for simulating the BME680 breakout board
  """
 
  # use ignore here to simulate a needed genserver method "start_link" 
  def start_link(_opts \\ []), do: :ignore

  def measure(_server) do
    {:ok, %BMP280.Measurement{
      temperature_c:       22.0,
      humidity_rh:         55.0,
      dew_point_c:         12.5,
      gas_resistance_ohms: 5578.28391904923,
      pressure_pa:         101_325.232232,
      altitude_m:          85.0,
      timestamp_ms:        System.monotonic_time(:millisecond)
    }}
  end

  def force_altitude(_server, _altitude), do: :ok
end
