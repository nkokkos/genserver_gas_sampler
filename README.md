# Gas Sensor Poncho Project

This is a [poncho project](https://embedded-elixir.com/post/2017-05-19-poncho-projects/) for Nerves that separates firmware from business logic, targeting **Raspberry Pi Zero W**.

## Target Platform

**Raspberry Pi Zero W** - The firmware is specifically built for this platform.

## Project Structure

```
genserver_gas_sampler/
├── README.md                    # This file
├── sampler/                     # Nerves firmware application
│   ├── lib/
│   │   ├── sampler.ex
│   │   └── sampler/
│   │       └── application.ex   # Supervisor that starts GasSensor + Web
│   ├── config/
│   │   ├── config.exs          # Main configuration
│   │   ├── host.exs            # Host development config
│   │   └── target.exs          # Target device config (WiFi, I2C)
│   ├── rootfs_overlay/
│   │   └── etc/
│   │       └── iex.exs         # IEx startup configuration
│   ├── mix.exs                 # Nerves dependencies
│   └── test/
├── gas_sensor/                  # OTP business logic (reusable library)
│   ├── lib/
│   │   ├── gas_sensor.ex
│   │   └── gas_sensor/
│   │       ├── application.ex  # OTP Application
│   │       └── sensor.ex       # GenServer for ADC reading
│   ├── config/
│   ├── mix.exs
│   └── test/
└── gas_sensor_web/              # Phoenix web interface
    ├── lib/
    │   ├── gas_sensor_web/
    │   │   └── application.ex  # Phoenix OTP Application
    │   └── gas_sensor_web_web/
    │       ├── endpoint.ex     # HTTP endpoint
    │       ├── router.ex       # Routes
    │       ├── live/           # LiveView modules
    │       │   ├── dashboard_live.ex
    │       │   └── sensor_live.ex
    │       └── components/     # UI components
    ├── config/
    └── mix.exs
```

## Quick Start

### 1. Build and test the gas_sensor library

```bash
cd gas_sensor
mix deps.get
mix test
```

### 2. Build firmware for Raspberry Pi Zero W

```bash
cd sampler
export MIX_TARGET=rpi0
mix deps.get
mix firmware
```

### 3. Deploy to SD card

Insert your SD card and run:

```bash
mix burn
```

## Web Interface

The project includes a Phoenix web interface accessible once the device is on WiFi:

- **Dashboard** (`http://<device-ip>/`) - Overview with visual PPM indicators
- **Detailed View** (`http://<device-ip>/sensor`) - Live sensor data with sample history
- **API** (`http://<device-ip>/api/readings/current`) - JSON API for integrations

The web interface updates in real-time using Phoenix LiveView (1-second refresh).

## Hardware Setup

### Components

- **Raspberry Pi Zero W** (with wireless)
- ADS1115 ADC connected via I2C
- Gas sensor (CO sensor with known sensitivity)
- Micro USB power supply

### Wiring

```
ADS1115      ->   Pi Zero W
-------          ---------
VDD          ->   3.3V (Pin 1)
GND          ->   GND  (Pin 6)
SDA          ->   GPIO 2 (Pin 3, I2C SDA)
SCL          ->   GPIO 3 (Pin 5, I2C SCL)
ADDR         ->   GND  (for address 0x48)
```

Connect your gas sensor output to ADS1115 AIN0/AIN1 for differential reading.

### I2C Address

Default: `0x48` (ADDR pin to GND)

## WiFi Configuration

Create a `wifi_credentials.json` file on the SD card's boot partition to configure WiFi:

```json
{
  "ssid": "YOUR_WIFI_SSID",
  "psk": "YOUR_WIFI_PASSWORD",
  "key_mgmt": "wpa_psk"
}
```

Or configure via IEx after first boot:

```elixir
VintageNet.configure("wlan0", %{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    networks: [%{
      ssid: "YOUR_WIFI_SSID",
      psk: "YOUR_WIFI_PASSWORD",
      key_mgmt: :wpa_psk
    }]
  },
  ipv4: %{method: :dhcp}
})
```

## Architecture

### gas_sensor OTP Application

A reusable OTP application that provides:

- **GasSensor.Sensor** - GenServer that:
  - Communicates with ADS1115 ADC via I2C
  - Samples 7 times over 5 seconds
  - Applies median filtering
  - Calculates CO concentration in PPM
  - Provides `get_ppm/0` and `get_state/0` APIs

Key features:
- Fault-tolerant (supervised restart on failure)
- Configurable I2C bus
- Calibrated for specific gas sensor
- Logging for debugging

### gas_sensor_web Phoenix Application

A lightweight Phoenix web interface that:

- **DashboardLive** (`/`) - Overview dashboard with:
  - Large PPM display with color-coded indicators
  - Air quality levels legend
  - Live update status
  
- **SensorLive** (`/sensor`) - Detailed view with:
  - Current PPM with status badge
  - Sample count and window size
  - Recent sample history (last 7 samples)
  
- **SensorController** - JSON API:
  - `GET /api/readings` - All available readings
  - `GET /api/readings/current` - Current reading only

Features:
- Real-time updates via LiveView (1-second polling)
- Minimal dependencies (Bandit web server, no database)
- Embedded CSS (no external assets needed)
- Mobile-responsive design

### sampler Nerves Application

Firmware that:
- Runs on Raspberry Pi Zero W
- Configures WiFi networking
- Starts GasSensor for I2C readings
- Starts GasSensorWeb for web interface
- Provides IEx helpers for interactive debugging

## Calibration

Edit `gas_sensor/lib/gas_sensor/sensor.ex` and update these values based on your sensor datasheet:

```elixir
# Sensor calibration constants
@sensitivity_na_per_ppm 1.827    # nA per ppm (from sensor label/datasheet)
@r3_ohms 1_200_000                 # Feedback resistor value
@divider_factor 2.0                 # Voltage divider factor
```

## Usage

### Interactive Shell (IEx)

Connect to your Pi Zero W via serial console or SSH, then:

```elixir
# Get current PPM reading
GasSensor.Sensor.get_ppm()

# Get full state for debugging
GasSensor.Sensor.get_state()

# Use helper for formatted output
Sampler.Helpers.gas_info()
```

### Web Interface

Once connected to WiFi, access the web interface:

1. Find the device IP (check your router or use `hostname -I` in IEx)
2. Open browser to `http://<device-ip>`
3. View real-time sensor readings

### From Your Code

```elixir
# The sensor is automatically supervised and started
# Just call the API:
ppm = GasSensor.Sensor.get_ppm()
Logger.info("Current CO level: #{ppm} ppm")
```

### JSON API

```bash
# Get current reading
curl http://<device-ip>/api/readings/current

# Response:
# {"ppm": 45.32, "status": "ok", "timestamp": "2024-01-15T10:30:00Z"}
```

## Development on Host

```bash
# Test business logic
cd gas_sensor
mix test

# Test web interface (without I2C hardware)
cd gas_sensor_web
mix phx.server
# Access at http://localhost:4000
```

## Pi Zero W Specific Notes

- **Power**: Use a good quality 2.5A+ power supply
- **I2C**: Enabled by default in Nerves systems
- **GPIO**: I2C pins are GPIO 2 (SDA) and GPIO 3 (SCL)
- **WiFi**: 2.4GHz only (802.11n)
- **Headless**: Designed to run without monitor/keyboard
- **Web Server**: Runs on port 80 (http://device-ip/)

## Dependencies

- [Nerves](https://hexdocs.pm/nerves) - Embedded framework
- [Nerves System RPi0](https://hexdocs.pm/nerves_system_rpi0) - Pi Zero W system
- [Circuits I2C](https://hexdocs.pm/circuits_i2c) - I2C communication
- [VintageNet](https://hexdocs.pm/vintage_net) - Networking
- [Phoenix](https://hexdocs.pm/phoenix) - Web framework
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) - Real-time UI

## References

- [ADS1115 Datasheet](https://www.ti.com/lit/ds/symlink/ads1115.pdf)
- [Nerves Project](https://nerves-project.org/)
- [Nerves Pi Zero System](https://github.com/nerves-project/nerves_system_rpi0)
- [Poncho Projects](https://embedded-elixir.com/post/2017-05-19-poncho-projects/)
- [Phoenix Framework](https://phoenixframework.org/)

## License

MIT License
