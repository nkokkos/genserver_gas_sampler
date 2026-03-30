defmodule Sampler do
  @moduledoc """
  Sampler Nerves Firmware

  This is the firmware application that runs on embedded hardware.
  It depends on the GasSensor OTP application for gas sensing functionality.

  ## Targets

  The firmware supports multiple Nerves targets:
  - Raspberry Pi (rpi, rpi0, rpi0_2, rpi2, rpi3, rpi3a, rpi4, rpi5)
  - BeagleBone Black (bbb)
  - OSD32MP1 (osd32mp1)
  - x86_64 (x86_64)

  ## Building

      # Set target (e.g., rpi4)
      export MIX_TARGET=rpi4
      
      # Get dependencies
      mix deps.get
      
      # Build firmware
      mix firmware
      
      # Burn to SD card
      mix burn

  ## Development on Host

      # Run on host (I2C will be stubbed)
      mix run
      
      # Or interactive shell
      iex -S mix
  """
end
