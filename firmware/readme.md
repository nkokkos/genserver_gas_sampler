# Elixir Nerves commands 
``
Application.started_applications
top()
cmd("free") or :erlang.memory()
VintageNet.info()
VintageNet.all_interfaces()
```

# Check all environment in the firmare:
```
Application.get_all_env(:firmware)
 ```

# Supervisor
example:
Supervisor.which_children(GasSensor.Supervisor)

# Check ETS memory usage
:ets.info(:your_table_name, :memory) * 8 / 1024 / 1024  # MB

# Check total memory
:erlang.memory()

# Async threads
:erlang.system_info(:thread_pool_size)i

# Upgrade Nerves
mix local.hex --force
mix local.rebar --force 
mix archive.install hex nerves_bootstrap --force

# Instructions on how to burn the sdcard when there no sdcard interface 
# on the pc. I assume the pc is arch linux:

# Install build dependencies - arch linux
sudo pacman -S git libusb base-devel

# Clone and build
git clone --depth=1 https://github.com/raspberrypi/usbboot
cd usbboot
make

# Run it (Pi connected to USB port, not PWR)
sudo ./rpiboot

# For rocky linux:
# Install build dependencies
sudo dnf install git libusb-devel gcc make

# Clone and build
git clone --depth=1 https://github.com/raspberrypi/usbboot
cd usbboot
make


# Run it (Pi connected to USB port, not PWR)
sudo ./rpiboot


# Install Elixir and Erlang - Archlinux
sudo pacman -S elixir erlang

# Install required tools - Arch Linux 
sudo pacman -S fwup squashfs-tools

# Install Nerves bootstrap

First read this: https://hexdocs.pm/nerves/installation.html
then do :
mix local.hex --force
mix local.rebar --force
mix archive.install hex nerves_bootstrap --force

# Create a Nerves Project:
mix nerves.new hello_nerves
cd hello_nerves

export MIX_TARGET=rpi0

mix deps.get
mix firmware

# Burn to sdcard

# Check device name
lsblk

# Burn (replace /dev/sdX)
mix firmware.burn /dev/sdX

# Check for firmware version on boot
Nerves.Runtime.KV.get_active("nerves_fw_version")
