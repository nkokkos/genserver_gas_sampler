import Config
# Enter here configuration for running on host
# For example, if you do export MIX_TARGET=host, 
# configuration will be read from this file
#
# Add configuration that is only needed when running on the host here.

# All should be loaded when we are running on host

config :gas_sensor,
  i2c_bus: "i2c-bus_stub",                       # the bus should be stubbed too.
  bme680_module: GasSensor.BME680.Stub,          # use stub in tests, not real sensor
  temp_path: "/tmp/thermal/thermal_zone0/temp",  # when testing on the host machine, make sure this file exists in you linux system:
  env: :host,                                    # This is for running on host, only for this OTP app. For GasSensor.Timestamp
  config: "/tmp/offset_config.json"              # This is for running on host, should create the file on linux on /tmp

# use this config example:
# https://github.com/nerves-project/nerves_examples/blob/main/poncho_phoenix/firmware/config/target.exs
config :gas_sensor_web, GasSensorWeb.Endpoint,
  url: [host: "tgs5042.local"],
  http: [port: 3001],
  http: [ip: {0,0,0,0}, port: 3001],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: "im2VAbnBXgHTrb6tJQzsS7w84jbfiMQ6A3jamHvnYiOR10y43E2hcoostekTHXVe",
  live_view: [signing_salt: "AqXWegTmfeVLuFlZFwnfUYz4c5WZur1VwzjgLKw/xgGGSEVGiLz3ZS4BqTYqdx3a"],
  check_origin: false,
  # Start the server since we're running in a release instead of through `mix`
  server: true,
  render_errors: [view: GasSensorWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GasSensorWeb.PubSub,
  # Nerves root filesystem is read-only, so disable the code reloader
  code_reloader: false,
  check_origin: false,
  adapter: Bandit.PhoenixAdapter

# Do not include metadata nor timestamps in development logs
#config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development

#config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
#config :phoenix, :plug_init_mode, :runtime

# Include HEEx debug annotations as HTML comments in rendered markup
#config :phoenix_live_view, :debug_heex_annotations, true



config :logger, backends: [RingLogger]

config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       # The KV store on Nerves systems is typically read from UBoot-env, but
       # this allows us to use a pre-populated InMemory store when running on
       # host for development and testing.
       #
       # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
       # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata

       "nerves_fw_active" => "a",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0"
     }}


