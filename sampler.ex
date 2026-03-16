# Code Starts here
defmodule SampleSensor do
  @moduledoc """
  GenServer for a Gas Sensor via ADS1115 ADC.
  Samples 7 times evenly spread over 5 seconds.
  Applies median filter and saves result to state.
  """
end
