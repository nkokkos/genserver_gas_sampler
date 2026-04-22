import Config

config :gas_sensor,
  # Default I2C bus - override in target.exs for specific hardware
  i2c_bus: "i2c-1"

# Target-specific configuration
import_config "#{Mix.target()}.exs"
