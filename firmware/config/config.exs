# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# Import the Config module that provides functions like config and import_config
import Config

# Enable the Nerves integration with Mix
# This is a build time command which starts the nerves bootstrap 
# application on the host machine(laptopm/linux system etc)
# It allows Mix to understand Nerves-specific commands and helps 
# manage the cross-compilation needed to build code for 
# a Raspberry Pi Zero from a non-Pi computer.
Application.start(:nerves_bootstrap)

# It stores the current build target into the application's environment
# For example, you set target to be rpi0 or something else
config :firmware, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.
# It points to a folder in the current project (firmware/rootfs_overlay)
# What it does: Anything we put in that folder, like a custom iex.exs or 
# some other script, will be copied directly to the rasberry pi's read 
# only system. Basically, this is a way to "inject" files to the Linux OS
config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1577975236"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.
# It replaces the standard Elixir console logger with RingLogger
# What it does: SDCards have a limited number of "writes" before they die.
# Ringlogger logs in a circular buffer in RAM rather than writing them to the
# SD card. This saves the hardware from wearing out and allows viewing logs
# by typing: RingLogger.new
config :logger, backends: [RingLogger]

# use shoehorn to handle otp application failures and load
# primary application components
# https://github.com/nerves-project/shoehorn

# shoehorn is configured in target.exs:
#config :shoehorn,
#  init: [:nerves_runtime, :nerves_pack],
#  app:  :firmware

# Picks ups configuration based on the host
# What it does: host.exs contains settings for our host(laptop). For 
# example using a fake Mock sensor
# Target.exs contains settings for the PI zero like wifi credentials, I2C bus
# addresses for the devices we will use
if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
