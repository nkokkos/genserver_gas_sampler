# Gas Sensor Livebook Notebooks

This folder contains ready-to-use Livebook notebooks for monitoring, debugging, and analyzing your gas sensor data from a Raspberry Pi Zero W.

## What is Livebook?

Livebook is an interactive notebook environment for Elixir that allows you to:
- Execute code remotely on your Pi
- Create real-time visualizations
- Monitor system health
- Debug issues interactively
- Export data for analysis

## Prerequisites

1. **Pi Zero W is booted** and on the same network as your laptop
2. **Know the Pi's IP address** (check via IEx with `VintageNet.info()`)
3. **Livebook installed** on your laptop:
   ```bash
   # macOS/Linux
   brew install livebook
   
   # Or via Elixir
   mix escript.install hex livebook
   ```
4. **Cookie configured** - Use the preset demo cookie: `gassensor_demo_cookie_2024`

## Quick Start

### 1. Start Livebook

```bash
livebook server --name livebook@YOUR_LAPTOP_IP --cookie gassensor_demo_cookie_2024
```

### 2. Open a Notebook

1. Open browser to `http://localhost:8080`
2. Click "Open" and select one of the `.livemd` files
3. Update the `pi_ip` variable to match your Pi's IP
4. Click "Evaluate" on code cells to connect

### 3. Explore

Each notebook has instructions and auto-updating visualizations!

---

## Notebook Descriptions

### 01_basic_dashboard.livemd
**Purpose:** Simple monitoring interface

**Features:**
- Current sensor reading display
- Recent samples table
- Basic statistics (median, average, min, max)
- System memory usage
- Process count
- Auto-refresh option

**Best for:** Quick health checks, verifying sensor is working

---

### 02_realtime_graph.livemd
**Purpose:** Real-time data visualization

**Features:**
- Live line chart of PPM over time
- Large current value display
- Bar chart of last 7 samples
- Color-coded threshold alerts
- Historical statistics tracking

**Best for:** Visual monitoring, detecting trends, setting up alerts

**Note:** Requires internet connection for VegaLite charts (loads JS libraries)

---

### 03_system_health.livemd
**Purpose:** Deep system monitoring

**Features:**
- Memory breakdown with pie chart
- Memory history over time
- Top processes by memory usage
- Application status
- Scheduler information
- System limits tracking
- Real-time system dashboard

**Best for:** Debugging performance issues, long-term stability monitoring

---

## How to Use

### Connecting to Your Pi

All notebooks have a "Setup" section at the top:

```elixir
# CHANGE THESE VALUES:
pi_ip = "192.168.1.45"        # Your Pi's IP address
cookie = "gassensor_demo_cookie_2024"
local_ip = "192.168.1.100"    # Your laptop's IP
```

**Finding your Pi's IP:**
- Via IEx on Pi: `VintageNet.info()`
- Via router admin page
- Via hostname: `ping nerves.local`

### Auto-Refreshing Charts

Notebooks with real-time features use `Kino.Frame.periodically`:
- Updates happen automatically
- Close the notebook tab to stop
- Adjust intervals by changing the millisecond value

### Exporting Data

To save data for analysis in other tools:

```elixir
# Get current dataset
data = :rpc.call(target_node, GasSensor.ReadingAgent, :get_reading, [])

# Export to CSV format
csv = """
Timestamp,PPM,Status
#{data.timestamp},#{data.ppm},#{data.status}
"""

# Write to file
File.write!("/path/to/export.csv", csv)
```

---

## Customization

### Adjusting Update Intervals

Find lines like:
```elixir
Kino.Frame.periodically(frame, 1000, fn _ ->
```

Change `1000` to desired milliseconds:
- `1000` = 1 second (real-time)
- `5000` = 5 seconds (less CPU intensive)
- `30000` = 30 seconds (long-term monitoring)

### Modifying Charts

VegaLite charts can be customized:

```elixir
VegaLite.new(width: 800, height: 400)  # Change size
|> VegaLite.mark(:bar)                   # Change to bar chart
|> VegaLite.encode_field(:color, :ppm,   # Add color encoding
    scale: [domain: [0, 100], range: ["green", "red"]]
  )
```

### Adding New Metrics

To monitor custom metrics:

```elixir
# Define fetch function
get_custom_metric = fn ->
  :rpc.call(target_node, YourModule, :your_function, [])
end

# Display in table
Kino.DataTable.new([
  %{metric: "Custom", value: get_custom_metric.()}
])
```

---

## Troubleshooting

### Connection Issues

**Problem:** `Node.connect` returns false

**Solutions:**
1. Verify Pi is booted: `ping PI_IP_ADDRESS`
2. Check EPMD on Pi: `:os.cmd('epmd -names')`
3. Verify cookie match: `Node.get_cookie()` on both sides
4. Check firewall: Port 4369 must be open

### Charts Not Rendering

**Problem:** VegaLite charts show blank or error

**Solutions:**
1. Check internet connection (loads JS from CDN)
2. Try refreshing the page
3. Open browser dev tools for JavaScript errors
4. Use basic `Kino.DataTable` instead for offline use

### RPC Timeouts

**Problem:** `:rpc.call` times out

**Solutions:**
1. Increase timeout: `:rpc.call(node, mod, fun, args, 30_000)`
2. Check Pi is responsive via ping
3. Verify target process is running
4. Reduce network load

### Data Not Updating

**Problem:** Auto-refresh charts are stuck

**Solutions:**
1. Re-run the setup cell to reconnect
2. Check `Node.list()` shows Pi node
3. Restart Livebook if connection lost
4. Verify sensor process hasn't crashed

---

## Advanced Usage

### Creating Custom Notebooks

1. Start with template:
```elixir
# Configuration
pi_ip = "192.168.1.45"
cookie = "gassensor_demo_cookie_2024"

# Connect
Node.start(:"livebook@192.168.1.100", :shortnames)
Node.set_cookie(String.to_atom(cookie))
target_node = :"sampler@#{pi_ip}"
Node.connect(target_node)
```

2. Add your analysis code
3. Use Kino for interactive elements
4. Save as `.livemd` file

### Scheduling Notebook Execution

To run notebooks automatically:

```bash
# Export notebook as script
livebook server --export script notebook.livemd

# Run via cron
*/5 * * * * /path/to/livebook/script.sh >> /var/log/sensor.log
```

### Multi-Device Monitoring

Monitor multiple sensors:

```elixir
# List of devices
devices = [
  %{name: "Living Room", node: :"sampler@192.168.1.45"},
  %{name: "Kitchen", node: :"sampler@192.168.1.46"},
  %{name: "Garage", node: :"sampler@192.168.1.47"}
]

# Connect to all
Enum.each(devices, fn dev ->
  Node.connect(dev.node)
end)

# Fetch from all
readings = Enum.map(devices, fn dev ->
  %{
    location: dev.name,
    ppm: :rpc.call(dev.node, GasSensor.ReadingAgent, :get_ppm, [])
  }
end)

Kino.DataTable.new(readings)
```

---

## Security Notes

### Current Configuration
- **Demo cookie:** `gassensor_demo_cookie_2024`
- **Distribution:** Enabled for debugging
- **Suitable for:** Development, demos, home use

### Production Considerations
1. **Change cookie** to secure random value
2. **Use VPN/SSH tunnel** instead of direct connection
3. **Disable distribution** when not debugging
4. **Firewall rules** for port 4369

See `LIVEBOOK_CONNECTION.md` for details.

---

## Files in This Directory

| File | Purpose | Complexity |
|------|---------|------------|
| `01_basic_dashboard.livemd` | Simple monitoring | ⭐ Beginner |
| `02_realtime_graph.livemd` | Visual charts | ⭐⭐ Intermediate |
| `03_system_health.livemd` | Deep diagnostics | ⭐⭐⭐ Advanced |
| `README.md` | This file | - |

---

## Resources

- **Livebook Docs:** https://livebook.dev/
- **Kino (visualizations):** https://hexdocs.pm/kino/
- **VegaLite (charts):** https://hexdocs.pm/vega_lite/
- **Project Docs:** See `LIVEBOOK_CONNECTION.md` in parent directory

---

## Tips

1. **Pin notebooks** you use frequently
2. **Fork before editing** to keep originals
3. **Export as Markdown** for documentation
4. **Use branches** in version control for different configurations
5. **Set up alerts** when PPM exceeds thresholds

---

**Happy Monitoring!** 📊🔬

For issues or questions, check the main project documentation.
