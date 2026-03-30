# COMPLETE BUILD GUIDE - Gas Sensor for Raspberry Pi Zero W

## What You Have Built

**Three OTP Applications that all run on Raspberry Pi Zero W:**

```
┌─────────────────────────────────────────┐
│         Raspberry Pi Zero W              │
│         (Nerves Firmware)                │
├─────────────────────────────────────────┤
│ gas_sensor_web (Port 80)                │
│ ├── Phoenix LiveView Dashboard          │
│ └── Reads from Agent (not I2C!)         │
├─────────────────────────────────────────┤
│ gas_sensor                               │
│ ├── ReadingAgent (data cache)           │
│ └── Sensor GenServer (I2C only)        │
├─────────────────────────────────────────┤
│ sampler (supervisor)                    │
│ └── Just coordinates, no work           │
├─────────────────────────────────────────┤
│ I2C Bus → ADS1115 → Gas Sensor         │
└─────────────────────────────────────────┘
```

## What Happens When You Boot the Pi?

### Step-by-Step Boot Process:

1. **Pi powers on** → BEAM VM (Erlang) starts
2. **OTP applications start automatically:**
   
   **First (0-2 seconds):** `gas_sensor` starts
   - ReadingAgent starts (empty state)
   - Sensor GenServer starts, opens I2C bus, begins reading
   
   **Second (2-4 seconds):** `gas_sensor_web` starts
   - Phoenix PubSub starts
   - Web server starts on port 80
   - Web pages ready but show "Sensor Not Started"
   
   **Third (4-5 seconds):** `sampler` starts
   - Just supervision, no new processes

3. **Sensor begins readings (immediately):**
   - Reads I2C every 714ms (7 samples in 5 seconds)
   - Updates ReadingAgent after each reading
   - Web pages now show real data

4. **Web interface live:**
   - Dashboard at `http://<pi-ip>/`
   - Live updates every second

## Build & Deploy Instructions

### Quick Build (One Command)

```bash
cd ~/elixir/genserver_gas_sampler
./build.sh
```

### Step-by-Step Build

```bash
# 1. Build business logic
cd ~/elixir/genserver_gas_sampler/gas_sensor
mix deps.get
mix compile

# 2. Build web interface
cd ~/elixir/genserver_gas_sampler/gas_sensor_web
mix deps.get
mix compile

# 3. Build firmware
cd ~/elixir/genserver_gas_sampler/sampler
export MIX_TARGET=rpi0
mix deps.get
mix firmware
```

### Deploy to SD Card

```bash
cd ~/elixir/genserver_gas_sampler/sampler
mix burn
```

**Insert SD card when prompted.**

## What Gets Compiled Into the Firmware?

When you run `mix firmware`, Nerves packages:

1. **Linux kernel** (from nerves_system_rpi0)
2. **Erlang VM** (BEAM)
3. **All 3 OTP apps compiled for ARM:**
   - gas_sensor (with circuits_i2c NIF for ARM)
   - gas_sensor_web (Phoenix templates compiled)
   - sampler (supervision code)
4. **Root filesystem** with configs
5. **Boot partition** with firmware loader

**Output:** Single `.fw` file (~40-50MB)

## SD Card Contents After Burn

```
SD Card
├── boot partition (FAT32)
│   ├── zImage (Linux kernel)
│   ├── erlinit (Erlang init)
│   ├── config.txt (Pi config)
│   └── ...
└── root partition (ext4)
    ├── /srv/erlang (OTP apps)
    │   ├── gas_sensor/ebin/*.beam
    │   ├── gas_sensor_web/ebin/*.beam
    │   └── sampler/ebin/*.beam
    ├── /usr/lib (NIFs - circuits_i2c)
    └── ...
```

## Verification After Boot

### Check All Apps Running

Connect via serial or SSH, then in IEx:

```elixir
# List all running OTP applications
Application.started_applications()

# Should show:
# [:gas_sensor, :gas_sensor_web, :sampler, :nerves_runtime, ...]

# Check I2C sensor
GasSensor.Sensor.get_state()
# Shows: %{i2c: #Reference<...>, ppm: 45.2, status: :ok, ...}

# Check Agent cache
GasSensor.ReadingAgent.get_reading()
# Shows: %{ppm: 45.2, window: [...], timestamp: ~U[...]}

# Check web server
GasSensorWeb.Endpoint.config(:http)
# Shows: [port: 80, ...]
```

### Check Web Interface

1. **Find Pi IP address:**
   ```elixir
   VintageNet.info()
   ```

2. **Open browser:**
   - `http://<pi-ip>/` → Dashboard
   - `http://<pi-ip>/sensor` → Detailed view

3. **Should see:**
   - PPM value updating every second
   - "Sensor Active" status
   - Sample count increasing

## Troubleshooting Boot Issues

### Apps Don't Start

Check logs:
```elixir
RingLogger.next
```

### I2C Errors

Check I2C bus:
```elixir
Circuits.I2C.detect("i2c-1")
# Should show device at 0x48 (ADS1115)
```

### Web Server Not Running

Check endpoint:
```elixir
Process.whereis(GasSensorWeb.Endpoint)
# Should return PID
```

### WiFi Not Connected

Configure WiFi:
```elixir
VintageNet.configure("wlan0", %{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    networks: [%{ssid: "YOUR_SSID", psk: "YOUR_PASS", key_mgmt: :wpa_psk}]
  },
  ipv4: %{method: :dhcp}
})
```

## Architecture Summary

**Why this design works for Pi Zero W:**

1. **All-in-one firmware:** Single `.fw` file contains everything
2. **No external deps:** Self-contained on SD card
3. **Headless operation:** No monitor/keyboard needed
4. **Web access:** Access from any device on network
5. **Power efficient:** I2C only accessed every 714ms
6. **Fault tolerant:** Each layer supervised independently

**Data flow on Pi:**
```
Hardware (I2C) → Sensor GenServer → ReadingAgent → Phoenix → Browser
   714ms           0ms update       0ms read       1s poll
```

## Files You Can Customize

Before building, edit these to match your hardware:

1. **Sensor calibration:**
   `gas_sensor/lib/gas_sensor/sensor.ex` (lines 49-52)
   - `@sensitivity_na_per_ppm`
   - `@r3_ohms`
   - `@divider_factor`

2. **I2C bus (if not i2c-1):**
   `gas_sensor/config/target.exs`
   - Change `i2c_bus: "i2c-1"`

3. **Web port (if not 80):**
   `sampler/config/target.exs`
   - Change `port: 80`

## Production Checklist

Before deploying:

- [ ] Calibrated sensor values in `sensor.ex`
- [ ] WiFi credentials configured
- [ ] I2C wiring verified with `Circuits.I2C.detect`
- [ ] Tested on bench power supply first
- [ ] SSH keys configured (optional)
- [ ] RingLogger configured for persistent logs (optional)

## Success Criteria

After booting Pi Zero W with your SD card:

✅ **Green LED blinks** (disk activity)  
✅ **All 3 OTP apps in `Application.started_applications()`**  
✅ **I2C sensor reading values**  
✅ **Agent has timestamped data**  
✅ **Web interface accessible at `http://<pi-ip>/`**  
✅ **PPM values updating every second**  

## Next Steps After Success

1. **WiFi setup:** Configure `wlan0` with your network
2. **Access web UI:** Find IP, open browser
3. **Monitor:** Check readings are reasonable for your sensor
4. **Calibrate:** Adjust constants if readings are off
5. **Deploy:** Install Pi in final location
6. **Monitor remotely:** Access dashboard from phone/laptop

## Emergency Recovery

If firmware won't boot:

1. Reformat SD card
2. Re-run `mix burn`
3. Check serial console for boot messages
4. Verify `config.txt` on boot partition

**Serial connection (for debugging):**
- GPIO 14 (TX) → USB TTL RX
- GPIO 15 (RX) → USB TTL TX  
- GND → GND
- 115200 baud
