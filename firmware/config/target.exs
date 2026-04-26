import Config

# Raspberry Pi Zero W specific configuration
# Optimized for 512MB RAM

# use example from the the poncho project file
config :ui, UiWeb.Endpoint,
  #url: [host: "nerves.local"],
  url: [host: "0.0.0.0"],
  http: [port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: "UPDATE_THIS_SECRET_KEY_BASE",
  live_view: [signing_salt: "UPDATE_THIS_SIGNING_SALT"],
  check_origin: false,
  # Start the server since we're running in a release instead of through `mix`
  server: false,
  render_errors: [view: UiWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Ui.PubSub,
  # Nerves root filesystem is read-only, so disable the code reloader
  code_reloader: false

# Configure networking (WiFi only on Pi Zero)
# Direct connections like those used for USB gadget connections
# regulator_domain keys: US, GR or 00 (world)

#config :vintage_net,
#  regulatory_domain: "00",
#  config: [
#    { "wlan0", %{  type: VintageNetWiFi    } }
#    { "usb0",  %{  type: VintageNetDirect  } }
#  ]

config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"usb0", %{type: VintageNetDirect}}, # Put the wired connection first
    {"wlan0",
      %{
        type: VintageNetWiFi,
        vintage_net_wifi: %{
          networks: [
            %{
              key_mgmt: :wpa_psk,
              ssid: "Your_Actual_SSID",
              psk: "Your_Actual_Password",
            }
          ]
        },
        ipv4: %{method: :dhcp},
      }
    } # Removed the trailing comma here because it's the last item
  ]

# Configure vintage net wizard:
# https://hexdocs.pm/vintage_net_wizard_launcher/readme.html
config :vintage_net_wizard,
  port: 8080,                    # Change this from the default 80
  dns_name: "tgs5042.config",    # The local URL for the wizard
  captive_portal: false

# Configure core app I2C settings
# This should copied to the config of the core app
#config :core, i2c_bus: "i2c-1",
# Firmware build date - used as base for provisional timestamps
# when offline (no WiFi/NTP). Update this when rebuilding firmware.
# firmware_build_date: ~U[2024-03-30 00:00:00Z]

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
config :nerves_time, :sync_interval, 600  # seconds

# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

# Please note!!
# 1. Before creating new keys, you should clear the old ones to avoid confusion. 
# In your terminal, run:
# rm ~/.ssh/id_rsa ~/.ssh/id_rsa.pub

# 2. Generate the New Key Pair
# Run the following command to create a new ED25519 key 
# (this is the modern, more secure standard, and it's much 
# shorter/cleaner for config files than the old RSA):
# ssh-keygen -t ed25519 -C "your_email@example.com"

# 3. Verify the Files Exist
# Run this to see your new keys:
# ls -l ~/.ssh/id_ed25519*

# Also note, that if you are using gadget mode and the nerves device is 
# assigned an ip of 172.31.177.161
# you need to do this: 
# ssh-keygen -R 172.31.177.161

keys =
  [
    Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"])
  ]
  |> Enum.filter(&File.exists?/1)

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    See your project's config.exs for this error message.
    """)

config :nerves_ssh,
  authorized_keys: Enum.map(keys, &File.read!/1)

config :mdns_lite,
  # The `host` key specifies what hostnames mdns_lite advertises.  `:hostname`
  # advertises the device's hostname.local. For the official Nerves systems, this
  # is "nerves-<4 digit serial#>.local".  mdns_lite also advertises
  # "nerves.local" for convenience. If more than one Nerves device is on the
  # network, delete "nerves" from the list.

  host: [:hostname, "nerves"],
  ttl: 120,

  # Advertise the following services over mDNS.
  services: [
    %{
      protocol: "ssh",
      transport: "tcp",
      port: 22
    },
    %{
      protocol: "sftp-ssh",
      transport: "tcp",
      port: 22
    },
    %{
      protocol: "epmd",
      transport: "tcp",
      port: 4369
    }
  ]

# Shoehorn configuration
config :shoehorn,
  init: [:nerves_runtime, :nerves_pack],
  app: Mix.Project.config()[:app]

# Nerves runtime configuration, this is defined on host
# config :nerves_runtime, :kernel, use_system_registry: true

# Configure Logger
# config :logger, RingLogger, persist_path: "/data/logs"

# Force the Erlang VM to dump its "Black Box" to the SD card on crash
config :nerves, :erl_init,
  env: [{"ERL_CRASH_DUMP", "/data/erl_crash.dump"}]

# Force RingLogger to write to the disk every 2 seconds
config :logger, RingLogger,
  persist_path: "/data/ring_logger",
  persist_interval: 2000, # Very aggressive for debugging
  max_size: 500,
  flush: true

# Logger configuration for embedded (reduce memory usage)
#config :logger,
#  level: :warning,
#  backends: [RingLogger],
#  ring_size: 1024,
#  flush: true

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

import_config "#{Mix.target()}.exs"

