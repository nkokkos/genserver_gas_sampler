import Config

# when testing on the host machine, make sure this file exists in you linux system:
# /tmp/thermal/thermal_zone0/temp
config :gas_sensor, temp_path: "/tmp/thermal/thermal_zone0/temp" 

# https://github.com/elixir-sensors/bmp280
# Read temperature and pressure from Bosch BMP180, 
# BMP280, BME280, and BME680 sensors in Elixir.
# Use the stubbed sensor when testing on host:

# when testing on the host machine, used stubbed sensor
config :gas_sensor, bme680_module: GasSensor.BME680.Stub
