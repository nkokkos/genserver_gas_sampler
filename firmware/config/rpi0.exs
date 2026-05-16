# Configuration for the Raspberry Pi Zero (target rpi0)

import Config

# On the Raspberry Pi Zero, the ACT LED is the small green light near the micro-USB power port.
# By default, Linux uses it to show SD card activity. In Nerves, we take control of it so it 
# can communicate your application's health and logic.

# This does not work for the indicators and delux.Leave it here for the time being.
# Just look in the application.ex file for more.
config :firmware,
  indicators: %{
    onboard_led: %{ # name for the LED group
      green: "ACT"  # Tells Delux to control the physical ACT LED
    }
  }

# https://elixirforum.com/t/independent-applications-as-local-dependencies/57109/3
# these keys will be available to rpi0 or real firmware on a real device
# Note that temp_path refers to a real path on the rasberry pi zero wireless

# This is our custom configuration for this project running on rpi0:
config :gas_sensor,
  i2c_bus: "i2c-1",
  bme680_module: BMP280,
  temp_path: "/sys/class/thermal/thermal_zone0/temp",
  env: :rpi0, # this is for picking the correct time if we are running on rasberry pi. Look inside the GasSensor.Timestamp module
  config: "/data/offset_config.json"  # this is for setting and saving the vsensor offset_config on the rasberry pi, look
                                      # in GasSensor.ConfigManager
 
# use this config example:
# https://github.com/nerves-project/nerves_examples/blob/main/poncho_phoenix/firmware/config/target.exs
config :gas_sensor_web, GasSensorWeb.Endpoint,
  url: [host: "tgs5042.local"],
  http: [port: 3001],
  http: [ip: {0,0,0,0}, port: 3001],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: "im2VAbnBXgHTrb6tJQzsS7w84jbfiMQ6A3jamHvnYiOR10y43E2hcoostekTHXVe",
  live_view: [signing_salt: "tX+xbzaV"]
  render_errors: [
    formats: [html: GasSensorWeb.ErrorHTML, json: GasSensorWeb.ErrorJSON],
    layout: false
  ],
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

