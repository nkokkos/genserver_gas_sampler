# gas_sensor/config/config.exs
import Config

# Keep in mind that:
# MIX_TARGET=host - the host mode or laptop mode
# Files Loaded: config.exs → host.exs.

# MIX_TARGET=rpi0 (The "Embedded" Mode)
# Files Loaded: config.exs → target.exs → rpi0.exs

# If you run tests or compile on host 
# then the keys :gas_sensor apply here only on this
# otp app: gas_sensor

# Note the differences between compile_env and get_env:

# compile_env -> baked into bytecode at mix compile time
# use for things that NEVER change per device
# for this example, this must be at 
# the application.ex file:
# @bme680 Application.compile_env(:gas_sensor, :bme680_module, BMP280)

# get_env -> read at runtime when app boots
# use for things that COULD change per device
# example: i2c_bus = Application.get_env(:gas_sensor, :i2c_bus, "i2c-1")

# defaults for running tests locally only in this OTP app

config :gas_sensor,
  i2c_bus: "i2c-bus_stub",              # the bus should be stubbed too.
  bme680_module: GasSensor.BME680.Stub  # use stub in tests, not real sensor

# when testing on the host machine, make sure this file exists in you linux system:
# /tmp/thermal/thermal_zone0/temp
config :gas_sensor, temp_path: "/tmp/thermal/thermal_zone0/temp"

# Target-specific configuration - We don't have more configurations
import_config "#{Mix.target()}.exs"
