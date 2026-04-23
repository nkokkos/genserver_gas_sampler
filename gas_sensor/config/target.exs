import Config

# Target device configuration for Raspberry Pi Zero W

# Configure NTP servers

# These can be customized in the application config

config :gas_sensor, i2c_bus: "i2c-1",

# When offline (no WiFi/NTP). Update this when rebuilding firmware.
# Firmware build date - used as base for provisional timestamps
config :gas_sensor, firmware_build_date: ~U[2026-04-22 00:00:00Z],

# Real path on the rasberry pi where the thermal zone is for cpu temperature
config :gas_sensor, temp_path: "/sys/class/thermal/thermal_zone0/temp",

config :gas_sensor, bme680_module: BMP280,
config :gas_sensor, elevation_m: 7 # this is the actual elevation at our house
