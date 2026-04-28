defmodule GasSensor.BME680.Stub do
  @moduledoc """
  Provides realistic random stub data for simulating the BME680 breakout board.
  Useful for testing Phoenix/Livebook visualizations and ThingsBoard logic.
  """
 
  # use ignore here to simulate a needed genserver method "start_link" 
  def start_link(_opts \\ []), do: :ignore

  def measure(_server) do
    # Generate slight fluctuations to simulate a real environment
    # temperature varies between 21.5 and 22.5
    temp = 22.0 + (:rand.uniform() - 0.5)
    # humidity varies between 54% and 56%
    hum = 55.0 + (:rand.uniform() * 2 - 1)
    # Gas resistance fluctuates more widely (typical for these sensors)
    gas_res = 5578.28 + (:rand.uniform() * 500 - 250)

    {:ok,
     %BMP280.Measurement{
       temperature_c: Float.round(temp, 2),
       humidity_rh: Float.round(hum, 2),
       dew_point_c: 12.5, # Keep constant or calculate if needed
       gas_resistance_ohms: gas_res,
       pressure_pa: 101_325.0 + :rand.uniform(10),
       timestamp_ms: System.monotonic_time(:millisecond)
     }}
  end

  # don't need this for our stub case
  # def force_altitude(_server, _altitude), do: :ok

end
