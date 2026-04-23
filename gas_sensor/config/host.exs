import Config

# Host configuration (for development and testing host without the rasberry pi )
config :gas_sensor,
  i2c_bus: "stub",
  build_date_source: ~U[2026-03-30 00:00:00Z],
  temp_path: "/tmp/thermal/thermal_zone0/temp"
  # when testing on the host machine,
  # make sure this file exists:
  # /tmp/thermal/thermal_zone0/temp
  bme680_module: BMP280,
  elevation_m: 7.0
