import Config

# Note:
#MIX_TARGET=host (The "Laptop" Mode)
#Files Loaded: config.exs → host.exs.

#MIX_TARGET=rpi0 (The "Embedded" Mode)
#Files Loaded: config.exs → target.exs → rpi0.exs

config :gas_sensor,
  # Default I2C bus - override in target.exs for specific hardware
  i2c_bus: "i2c-1"

# When offline (no WiFi/NTP). Update this when rebuilding firmware.
# Firmware build date - used as base for provisional timestamps
# This captures the time on your laptop/build machine AT COMPILE TIME
# config :gas_sensor, firmware_build_date: DateTime.utc_now()
# example for hardcoded build date:
config :gas_sensor, firmware_build_date: ~U[2026-04-22 00:00:00Z]

# Target-specific configuration
import_config "#{Mix.target()}.exs"
