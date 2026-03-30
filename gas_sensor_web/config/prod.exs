import Config

# Production/Erlang release configuration for Raspberry Pi Zero W
# Optimized for 512MB RAM constraint

config :gas_sensor_web, GasSensorWeb.Endpoint,
  url: [host: "0.0.0.0", port: 80],
  http: [
    ip: {0, 0, 0, 0},
    port: 80,
    # Optimize for Pi Zero W memory constraints
    # Reduce acceptors and max connections
    thousand_island_options: [
      num_acceptors: 5,
      max_connections: 50
    ]
  ],
  server: true,
  check_origin: false,
  # Minimal secret for embedded device
  secret_key_base: "embedded_gas_sensor_secret_key_base_for_pi_zero_w",
  # Disable code reloading in production
  code_reloader: false,
  # Disable debug output
  debug_errors: false

# Log only warnings and errors to reduce I/O
config :logger, level: :warning

# Configure Phoenix for embedded deployment
config :phoenix, :plug_init_mode, :runtime

# LiveView configuration for low-memory environment
config :phoenix_live_view,
  # Disable debugging in production
  debug_heex_annotations: false,
  # Optimize DOM operations
  enable_expensive_runtime_checks: false

# Bandit/Thousand Island optimized settings for Pi Zero
config :bandit,
  # Reduce memory footprint
  compressed: false
