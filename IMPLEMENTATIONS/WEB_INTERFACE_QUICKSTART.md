# Gas Sensor Web Interface - Quick Start

## What You Built

A complete Phoenix web application integrated into your Nerves poncho project with:

- **Real-time LiveView dashboard** showing gas sensor readings
- **Visual indicators** (green/yellow/red) based on PPM levels
- **JSON API** for programmatic access
- **Mobile-responsive design** optimized for Pi Zero W

## Project Structure

```
gas_sensor_web/           # NEW: Phoenix web app
├── lib/
│   ├── gas_sensor_web/
│   │   ├── application.ex     # OTP Application supervisor
│   │   └── telemetry.ex       # Metrics
│   └── gas_sensor_web_web/
│       ├── endpoint.ex        # HTTP endpoint (Bandit server)
│       ├── router.ex          # Routes (/ and /sensor)
│       ├── live/
│       │   ├── dashboard_live.ex   # Dashboard at /
│       │   └── sensor_live.ex    # Detailed view at /sensor
│       ├── components/
│       │   ├── layouts/
│       │   │   └── root.html.heex  # Embedded CSS layout
│       │   └── core_components.ex  # UI components
│       └── controllers/
│           └── sensor_controller.ex  # JSON API
├── config/
│   ├── config.exs
│   ├── dev.exs              # Port 4000, dev mode
│   ├── prod.exs             # Port 80, production
│   └── test.exs
└── mix.exs                  # Phoenix + LiveView deps
```

## Key Features

### Dashboard (`/`)
- Large PPM display with color coding
- Air quality levels legend
- Live update indicator
- Navigation to detailed view

### Detailed View (`/sensor`)
- Current PPM with status badge
- Sample count and window size
- Recent sample history (last 7 readings)
- Auto-refresh every second

### JSON API
```bash
GET /api/readings/current
# Returns: {"ppm": 45.32, "status": "ok", "timestamp": "2024-01-15T10:30:00Z"}

GET /api/readings
# Returns: All available readings
```

## Building & Deploying

### 1. Build firmware (same as before)

```bash
cd ~/elixir/genserver_gas_sampler/sampler
export MIX_TARGET=rpi0
mix deps.get
mix firmware
```

### 2. Deploy to SD card

```bash
mix burn
```

### 3. Connect to WiFi

The Phoenix server starts automatically. Configure WiFi via IEx:

```elixir
VintageNet.configure("wlan0", %{
  type: VintageNetWiFi,
  vintage_net_wifi: %{
    networks: [%{
      ssid: "YOUR_SSID",
      psk: "YOUR_PASSWORD",
      key_mgmt: :wpa_psk
    }]
  },
  ipv4: %{method: :dhcp}
})
```

### 4. Access the web interface

Find your device's IP address:
```elixir
# In IEx
:inet.getifaddrs()
```

Then open browser to:
- Dashboard: `http://<device-ip>/`
- Detailed view: `http://<device-ip>/sensor`
- API: `http://<device-ip>/api/readings/current`

## Development (Host)

Test the web interface locally:

```bash
cd ~/elixir/genserver_gas_sampler/gas_sensor_web
mix deps.get
mix phx.server
# Access at http://localhost:4000
```

Note: I2C will fail gracefully on host, showing "Sensor Not Started" status.

## How It Works

1. **GasSensor.Sensor** (in gas_sensor app) reads from ADC every 714ms
2. **Sampler.Application** starts both the sensor and web endpoint
3. **LiveView** polls the GenServer state every second via `Process.whereis/1`
4. **Updates** are pushed to connected browsers automatically
5. **CSS** is embedded in the layout (no external asset pipeline needed)

## Technical Highlights

- **Bandit** web server (lighter than Cowboy)
- **No database** (data comes from GenServer state)
- **Embedded CSS** (Tailwind-like classes in HTML head)
- **Minimal deps** (Phoenix, LiveView, Bandit)
- **Lightweight** for Pi Zero W constraints

## Next Steps

1. **Test locally**: `cd gas_sensor_web && mix phx.server`
2. **Build firmware**: Follow steps above
3. **Deploy and test**: Connect to device WiFi and view dashboard
4. **Customize**: Edit `dashboard_live.ex` or `sensor_live.ex` to change UI
5. **Add features**: Add more routes, charts, or historical data storage

## Files to Customize

- `gas_sensor_web/lib/gas_sensor_web_web/live/dashboard_live.ex` - Main dashboard UI
- `gas_sensor_web/lib/gas_sensor_web_web/live/sensor_live.ex` - Detailed view UI
- `gas_sensor_web/lib/gas_sensor_web_web/components/layouts/root.html.heex` - CSS styling
- `gas_sensor/lib/gas_sensor/sensor.ex` - Sensor calibration values

## Troubleshooting

### Web server doesn't start
Check logs in IEx:
```elixir
RingLogger.next
```

### Can't access web interface
Verify WiFi is connected and get IP:
```elixir
VintageNet.info()
```

### Sensor shows "Not Started"
Ensure `GasSensor.Sensor` is running:
```elixir
Process.whereis(GasSensor.Sensor)
```

### High CPU usage
The LiveView polls every second. Reduce frequency in `sensor_live.ex`:
```elixir
# Change from 1000ms to 5000ms for 5-second updates
:timer.send_interval(5000, self(), :update_reading)
```
