import Config

# Host configuration (for development and testing host without the rasberry pi )
config :gas_sensor, i2c_bus: "i2c_bus_stub"

# When offline (no WiFi/NTP). Update this when rebuilding firmware.
# Firmware build date - used as base for provisional timestamps
# This captures the time on your laptop/build machine AT COMPILE TIME
config :gas_sensor, firmware_build_date: DateTime.utc_now()
# config :gas_sensor, build_date_source: ~U[2026-03-30 00:00:00Z]

# when testing on the host machine, make sure this file exists in you linux system:
# /tmp/thermal/thermal_zone0/temp
config :gas_sensor, temp_path: "/tmp/thermal/thermal_zone0/temp" 

# https://github.com/elixir-sensors/bmp280
# Read temperature and pressure from Bosch BMP180, 
# BMP280, BME280, and BME680 sensors in Elixir.
# Use the stubbed sensor when testing on host:
config :gas_sensor, bme680_module: GasSensor.BME680.Stub
