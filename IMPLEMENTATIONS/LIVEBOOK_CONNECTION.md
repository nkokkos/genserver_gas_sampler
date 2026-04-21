# Connecting to Nerves Device via Livebook

This guide explains how to connect to your running Raspberry Pi Zero W using Livebook for remote monitoring, debugging, and interactive development.

## Overview

**What is Livebook?**
- Interactive notebook environment for Elixir
- Runs on your laptop/desktop
- Connects to remote Elixir nodes (like your Pi Zero)
- Provides rich visualizations, graphs, and interactive widgets
- Perfect for monitoring sensor data in real-time

**Connection Architecture:**
```
Your Laptop (Livebook)
      │
      │ SSH/EPMD (port 4369 + dynamic)
      │ Cookie: gassensor_demo_cookie_2024
      │
      ▼
Raspberry Pi Zero W (Nerves)
      ├── gas_sensor OTP app
      ├── gas_sensor_web OTP app
      └── sampler OTP app
```

## Prerequisites

### 1. Rebuild Firmware with Cookie (Already Done)

The firmware is configured with a preset cookie:
- **Cookie value:** `gassensor_demo_cookie_2024`
- **Node name:** `sampler@nerves.local`

If you haven't rebuilt yet:
```bash
cd ~/elixir/genserver_gas_sampler/sampler
export MIX_TARGET=rpi0
mix firmware
mix burn
```

### 2. Install Livebook on Your Laptop

```bash
# Using Homebrew (macOS/Linux)
brew install livebook

# Or using Elixir
mix escript.install hex livebook

# Or as a Docker container
docker pull livebook/livebook
```

### 3. Network Requirements

- Your laptop and Pi Zero must be on the **same network**
- Pi Zero must have **WiFi configured** and connected
- Firewall must allow port **4369** (EPMD) and dynamic ports

## Step-by-Step Connection

### Step 1: Find Your Pi's IP Address

Once the Pi is booted, check its IP:

**Via serial console (IEx):**
```elixir
# Option 1: VintageNet
VintageNet.info()

# Option 2: Network interfaces
:inet.getifaddrs()

# Option 3: Check routing
cmd("ip addr show wlan0")
```

**Typical output:**
```
# Example: Pi is at 192.168.1.45
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 192.168.1.45/24 brd 192.168.1.255 scope global dynamic wlan0
```

**Note the IP address** (e.g., `192.168.1.45`)

### Step 2: Verify Distribution is Running

On the Pi (via IEx):
```elixir
# Check if node is visible
Node.self()
# Should return: :"sampler@nerves.local"

# Check connected nodes
Node.list()
# Should return: [] (empty until Livebook connects)

# Check EPMD is running
cmd("epmd -names")
# Should show: epmd: up and running on port 4369 with data:
# name sampler at port 12345
```

### Step 3: Start Livebook with Cookie

On your laptop:

```bash
# Option A: Using environment variable (recommended)
export ERL_COOKIE="gassensor_demo_cookie_2024"
export ERL_AFLAGS="-name livebook@192.168.1.100 -setcookie $ERL_COOKIE"

livebook server

# Option B: Using command line flags
livebook server \
  --name livebook@192.168.1.100 \
  --cookie gassensor_demo_cookie_2024

# Option C: Using Docker
docker run -p 8080:8080 \
  -e LIVEBOOK_COOKIE=gassensor_demo_cookie_2024 \
  -e LIVEBOOK_NODE=livebook@192.168.1.100 \
  livebook/livebook
```

**Replace `192.168.1.100` with your laptop's IP address**

### Step 4: Connect to Remote Node

In Livebook:

1. **Open Livebook** in browser (http://localhost:8080)
2. **Create a new notebook**
3. **Set runtime to "Embedded"**
4. **Connect to remote node** using this code:

```elixir
# Attach to the Pi Zero node
Node.start(:"livebook@192.168.1.100", :shortnames)
Node.set_cookie(:"gassensor_demo_cookie_2024")

# Connect to the Pi
Node.connect(:"sampler@192.168.1.45")

# Verify connection
Node.list()
# Should show: [:"sampler@192.168.1.45"]
```

**Note:** Use the Pi's IP address directly (not `nerves.local`) for more reliable connections:
```elixir
Node.connect(:"sampler@192.168.1.45")
```

### Step 5: Execute Remote Code

Now you can run code on the Pi from Livebook:

```elixir
# Get current sensor reading (executes on Pi)
:rpc.call(:"sampler@192.168.1.45", GasSensor.ReadingAgent, :get_reading, [])

# Get just the PPM
:rpc.call(:"sampler@192.168.1.45", GasSensor.ReadingAgent, :get_ppm, [])

# Get full state from GenServer
:rpc.call(:"sampler@192.168.1.45", GasSensor.Sensor, :get_state, [])

# Check memory usage on Pi
:rpc.call(:"sampler@192.168.1.45", :erlang, :memory, [])
```

## Useful Livebook Monitoring Code

### Real-Time Sensor Dashboard

Create a Livebook cell with this code:

```elixir
# Configure the remote node target
target_node = :"sampler@192.168.1.45"

# Function to fetch current reading
fetch_reading = fn ->
  :rpc.call(target_node, GasSensor.ReadingAgent, :get_reading, [])
end

# Display current reading
reading = fetch_reading.()

Kino.DataTable.new([
  %{metric: "PPM", value: reading.ppm},
  %{metric: "Status", value: reading.status},
  %{metric: "Sample Count", value: reading.sample_count},
  %{metric: "Last Update", value: reading.timestamp}
])
```

### Live Graph of Sensor Data

```elixir
# Create a frame for live updates
frame = Kino.Frame.new()

# Start data collection
Kino.Frame.render(frame, "Starting sensor monitoring...")

data_stream = Stream.interval(1000)  # Update every second
|> Stream.map(fn _ ->
  reading = :rpc.call(target_node, GasSensor.ReadingAgent, :get_reading, [])
  %{time: Time.utc_now(), ppm: reading.ppm}
end)
|> Enum.take(60)  # Collect 60 seconds of data

# Create a simple line chart
VegaLite.new(width: 400, height: 200)
|> VegaLite.data_from_values(data_stream)
|> VegaLite.mark(:line)
|> VegaLite.encode_field(:x, :time, type: :temporal)
|> VegaLite.encode_field(:y, :ppm, type: :quantitative)
```

### Check System Health

```elixir
# Memory usage on Pi
memory = :rpc.call(target_node, :erlang, :memory, [])

# Format nicely
memory_mb = Enum.map(memory, fn {k, v} -> 
  {k, Float.round(v / 1024 / 1024, 2)} 
end)

Kino.DataTable.new([
  %{type: "Total", mb: memory_mb[:total]},
  %{type: "Processes", mb: memory_mb[:processes]},
  %{type: "System", mb: memory_mb[:system]},
  %{type: "ETS", mb: memory_mb[:ets]}
])
```

### Process Information

```elixir
# List running processes on Pi
processes = :rpc.call(target_node, :erlang, :system_info, [:process_count])

# Get specific process info
sensor_pid = :rpc.call(target_node, Process, :whereis, [GasSensor.Sensor])
sensor_info = :rpc.call(target_node, Process, :info, [sensor_pid])

Kino.DataTable.new([
  %{info: "Total Processes", value: processes},
  %{info: "Sensor PID", value: inspect(sensor_pid)},
  %{info: "Sensor Memory", value: sensor_info[:memory]}
])
```

## Troubleshooting Connection Issues

### Issue 1: Cannot Connect

**Symptoms:**
```
Node.connect returns false
Node.list returns []
```

**Solutions:**

1. **Check network connectivity:**
```bash
# From your laptop
ping 192.168.1.45
```

2. **Verify EPMD is running on Pi:**
```elixir
# On Pi via IEx
cmd("epmd -names")
# Should show sampler node registered
```

3. **Check firewall:**
```bash
# On Pi
cmd("iptables -L")
# Port 4369 must be open
```

4. **Verify cookie matches:**
```elixir
# On Pi
Node.get_cookie()
# Should return: :gassensor_demo_cookie_2024

# In Livebook
Node.get_cookie()
# Must match exactly
```

### Issue 2: Connection Drops

**Symptoms:**
- Intermittent connectivity
- RPC calls fail randomly

**Solutions:**

1. **Use IP addresses instead of hostnames:**
```elixir
# More reliable
Node.connect(:"sampler@192.168.1.45")

# Instead of
Node.connect(:"sampler@nerves.local")
```

2. **Set longer timeouts:**
```elixir
:rpc.call(node, mod, fun, args, 30_000)  # 30 second timeout
```

3. **Check WiFi stability:**
```elixir
# On Pi
VintageNet.info()
# Look for signal strength
```

### Issue 3: Cookie Mismatch

**Symptoms:**
```
** (ErlangError) Erlang error: :not_allowed
```

**Fix:**
```elixir
# In Livebook - set cookie BEFORE connecting
Node.set_cookie(:"gassensor_demo_cookie_2024")
Node.connect(:"sampler@192.168.1.45")
```

### Issue 4: Cannot Start Livebook Node

**Symptoms:**
```
** (MatchError) no match of right hand side value: {:error, _}
```

**Fix:**
```bash
# Use shortnames (easier for local networks)
livebook server --name livebook@127.0.0.1

# Then in Livebook
Node.start(:"livebook@127.0.0.1", :shortnames)
```

## Security Considerations

### For Production (NOT Demo):

1. **Change the cookie to a secure random value:**
```elixir
# Generate secure cookie
cookie = :crypto.strong_rand_bytes(32) |> Base.encode64()

# Set via environment variable
export ERL_COOKIE="your-secure-cookie-here"
```

2. **Update both firmware and Livebook:**
```bash
# Build with env var
cd sampler
ERL_COOKIE="your-secure-cookie" mix firmware
```

3. **Use SSH tunnel instead of direct connection:**
```bash
ssh -L 4369:localhost:4369 pi@192.168.1.45
```

4. **Disable distribution when not needed:**
```erlang
# Comment out in vm.args.eex
# -name sampler@nerves.local
# -setcookie ...
```

## Alternative: Using Nerves CLI

If Livebook connection is complex, use built-in Nerves tools:

### Via SSH

```bash
# Connect to Pi via SSH
ssh nerves@192.168.1.45

# Get IEx shell
iex

# Run commands directly
GasSensor.ReadingAgent.get_reading()
```

### Via Firmware Update Script

```bash
# Generate upload script
cd sampler
mix firmware.gen.script

# This creates upload.sh for remote updates
./upload.sh 192.168.1.45
```

## Quick Reference Card

```elixir
# Connection sequence
Node.start(:"livebook@YOUR_LAPTOP_IP", :shortnames)
Node.set_cookie(:"gassensor_demo_cookie_2024")
Node.connect(:"sampler@PI_ZERO_IP")

# Verify
Node.list()  # Should show Pi node

# Remote execution
:rpc.call(:"sampler@PI_ZERO_IP", Module, :function, [args])

# Common commands
:rpc.call(node, GasSensor.ReadingAgent, :get_reading, [])
:rpc.call(node, GasSensor.ReadingAgent, :get_ppm, [])
:rpc.call(node, :erlang, :memory, [])
:rpc.call(node, :erlang, :system_info, [:process_count])
```

## Summary

With the preset cookie `gassensor_demo_cookie_2024`:

1. ✅ **Rebuild firmware** (already configured)
2. ✅ **Boot Pi Zero** and get IP address
3. ✅ **Start Livebook** with matching cookie
4. ✅ **Connect** using `Node.connect`
5. ✅ **Monitor and debug** remotely!

**Demo cookie:** `gassensor_demo_cookie_2024`
**Node name:** `sampler@nerves.local` (or IP)
**Ports:** 4369 (EPMD) + dynamic allocation

Happy monitoring! 📊🔬
