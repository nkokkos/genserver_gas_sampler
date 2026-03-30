import Config

# Raspberry Pi Zero W specific configuration
# Optimized for 512MB RAM

# Configure networking (WiFi only on Pi Zero)
config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"wlan0", %{type: VintageNetWiFi}}
  ]

# Configure gas_sensor I2C settings
config :gas_sensor,
  i2c_bus: "i2c-1",
  # Firmware build date - used as base for provisional timestamps
  # when offline (no WiFi/NTP). Update this when rebuilding firmware.
  firmware_build_date: ~U[2024-03-30 00:00:00Z]

# Configure NTP servers for time synchronization
# These are used by nerves_time to sync system clock
# You can specify custom servers here (e.g., your own NTP server)
config :nerves_time, :servers, [
  # Default NTP pool servers (recommended for most users)
  "0.pool.ntp.org",
  "1.pool.ntp.org",
  "2.pool.ntp.org",
  "3.pool.ntp.org"

  # Regional servers (uncomment for better performance in your region)
  # "0.us.pool.ntp.org",  # North America
  # "0.europe.pool.ntp.org",  # Europe
  # "0.asia.pool.ntp.org",  # Asia

  # Custom/internal NTP servers (add your own)
  # "ntp.mycompany.local",  # Internal company server
  # "192.168.1.1",          # Router with NTP
  # "10.0.0.1",             # Local network NTP
]

# Optional: Configure NTP sync interval (default is every 11 minutes)
# config :nerves_time, :sync_interval, 600  # seconds

# Configure gas_sensor_web for production on device
config :gas_sensor_web, GasSensorWeb.Endpoint,
  url: [host: "0.0.0.0", port: 80],
  server: true,
  check_origin: false

# Shoehorn configuration
config :shoehorn,
  init: [:nerves_runtime, :nerves_pack],
  app: Mix.Project.config()[:app]

# Nerves runtime configuration
config :nerves_runtime, :kernel, use_system_registry: true

# Logger configuration for embedded (reduce memory usage)
config :logger,
  level: :warning,
  backends: [RingLogger],
  ring_size: 1024,
  flush: true
