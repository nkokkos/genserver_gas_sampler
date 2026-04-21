import Config

# Host configuration (for development and testing)
config :gas_sensor,
  i2c_bus: "stub"

config :gas_sensor, 
  :build_date_source, ~U[2026-03-30 00:00:00Z]
