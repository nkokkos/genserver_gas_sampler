import Config

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

# Save messages to one circular buffer that holds 1024 entries.
config :logger, RingLogger,
  persist_path: "/data/ring_logger.log",
  persist_seconds: 2000,
  max_size: 1024

# Use shoehorn to start the main application. See the shoehorn
# library documentation for more control in ordering how OTP
# applications are started and handling failures.

config :shoehorn, init: [:nerves_runtime, :nerves_pack]

# Enable the system startup guard to check that all OTP applications
# started. If they didn't and you're on a Nerves system that supports
# test runs of new firmware, the firmware will automatically roll
# back to the previous version. Delete this if implementing your own
# way of validating that firmware is good.
config :nerves_runtime, startup_guard_enabled: true

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

# Advance the system clock on devices without a real-time clock.
config :nerves, :erlinit, update_clock: true

# Force the Erlang VM to dump its "Black Box" to the SD card on crash
config :nerves, :erlinit,
  env: "ERL_CRASH_DUMP=/data/erl_crash.dump"

# Configure networking (WiFi only on Pi Zero)
# Direct connections like those used for USB gadget connections
# regulator_domain keys: US, GR or 00 (world)

#config :vintage_net,
#  regulatory_domain: "00",
#  config: [
#    { "wlan0", %{  type: VintageNetWiFi    } }
#    { "usb0",  %{  type: VintageNetDirect  } }
#  ]

# There should be an .env file at the root of this otp app
# Before mix firmware, do: source .env
# For example:
# .env (DO NOT COMMIT THIS FILE .env)
# export NERVES_WIFI_SSID="Your_SSID"
# export NERVES_WIFI_PASS="Your_Password"

config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"usb0", %{type: VintageNet.Technology.Gadget}}, # Put the wired connection first
    {"wlan0",
      %{
        type: VintageNet.Technology.WiFi,
        vintage_net_wifi: %{
          networks: [
            %{
              key_mgmt: :wpa_psk,
              ssid: System.get_env("NERVES_WIFI_SSID"),
              psk:  System.get_env("NERVES_WIFI_PASS")    
            }
          ]
        },
        ipv4: %{method: :dhcp},
      }
    }
  ]

# Configure vintage net wizard:
# https://hexdocs.pm/vintage_net_wizard_launcher/readme.html
# https://hexdocs.pm/vintage_net_wizard/readme.html#configuration
# Note that the documented way to launch the wizard with the captive_portal:false is this
# VintageNetWizard.run_wizard(captive_portal: false) # as a runtime option

config :vintage_net_wizard,
  ssid: "TGS5042-Setup",         # This needs to be tested. The ap mode should display this.
  port: 8080,                    # Change this from the default 80
  dns_name: "tgs5042",           # The local URL for the wizard. For example: http://tgs5042.local
                                 # default is "wifi.config"

  captive_portal: false          # This disables the feature that 
                                 # automatically "pops up" the login window when a 
                                 # device connects to the Nerves WiFi access point.


# Configure Nerves Time:
# Basically, block device startup for 5 seconds waiting for NTP response
config :nerves_time, await_initialization_timeout: :timer.seconds(5)

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
  # "0.us.pool.ntp.org",        # North America
  # "0.europe.pool.ntp.org",    # Europe
  # "0.asia.pool.ntp.org",      # Asia

  # Custom/internal NTP servers (add your own)
  # "ntp.mycompany.local",      # Internal company server
  # "192.168.1.1",              # Router with NTP
  # "10.0.0.1",                 # Local network NTP
]

# This section is important. Please read it carefully!
# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

# Read carefully about the ssh keys:

# Step 1. Before creating new keys, you should clear the old ones to avoid confusion. 
# In your terminal, run:
# rm ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
# rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub  

# Step 2. Generate the New Key Pair
# Run the following command to create a new ED25519 key (this is the modern, more secure standard, 
# and it's much shorter/cleaner for config files than the old RSA):
# ssh-keygen -t ed25519 -C "your_email@example.com"

# Step 3. Verify that the files exist
# Run this to see your new keys:
# ls -l ~/.ssh/id_ed25519*

# Step 4. Verify ssh connection 
# If you have problem connecting to the nerves device and if you are using gadget mode 
# and the nerves device is assigned an ip of 172.31.177.161, you need to do this: 
# ssh-keygen -R 172.31.177.161
# When you run ssh-keygen -R 172.31.177.161, you are telling your computer to forget 
# the specific digital fingerprint (the public host key) associated with that IP address.
# It might work for the direct ip connections too.

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

  host: [:hostname, "tgs5042"],
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
    },
    %{
      protocol: "erlang-dist", 
      transport: "tcp", 
      port: 4370
     }
  ]

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations
import_config "#{Mix.target()}.exs"

