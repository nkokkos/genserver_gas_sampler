import Config

config :gas_sensor, i2c_bus: "i2c-1"

# Real path on the rasberry pi where the thermal zone is for cpu temperature
config :gas_sensor, temp_path: "/sys/class/thermal/thermal_zone0/temp"

# https://github.com/elixir-sensors/bmp280
# Read temperature and pressure from Bosch BMP180,
# BMP280, BME280, and BME680 sensors in Elixir.
config :gas_sensor, bme680_module: BMP280

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations
# this will import the rpi0.ex file:
import_config "#{Mix.target()}.exs"

