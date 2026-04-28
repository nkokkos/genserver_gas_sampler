defmodule GasSensor do
  @moduledoc """
  GasSensor is an OTP application for reading: 
  1. Temperature from the BME680 breakout board. 
  2. Voltage from a adc1115adc breakout board which is connected to a TGS5042 gas sensor

  ## Features

  - Reads from ADS1115 ADC via I2C
  - Median filtering (11 samples every 10seconds)
  - PPM calculation with configurable calibration
  - GenServer-based for fault tolerance

  ## Usage

      # Get current reading
      ppm = Core.Sensor.get_ppm()
      
      # Get full state
      state = Core.Sensor.get_state()
  """
end
