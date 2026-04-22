import Config

# Target device configuration for Raspberry Pi Zero W

# Configure NTP servers

# These can be customized in the application config
config :gas_sensor,
  i2c_bus: "i2c-1",
  # Firmware build date - used as base for provisional timestamps
  # when offline (no WiFi/NTP). Update this when rebuilding firmware.
  firmware_build_date: ~U[2026-04-22 00:00:00Z],
  temp_path: "/sys/class/thermal/thermal_zone0/temp"
