defmodule Core do
  @moduledoc """
  Core is an OTP application for reading gas sensor data via ADS1115 ADC.

  ## Features

  - Reads from ADS1115 ADC via I2C
  - Median filtering (7 samples over 5 seconds)
  - PPM calculation with configurable calibration
  - GenServer-based for fault tolerance

  ## Usage

      # Get current reading
      ppm = Core.Sensor.get_ppm()
      
      # Get full state
      state = Core.Sensor.get_state()
  """
end
