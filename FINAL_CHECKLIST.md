# FINAL VERIFICATION - All 3 Apps on Pi Zero W with Livebook Support

## Status: ✅ READY TO BUILD

All three OTP applications are correctly configured to run on Raspberry Pi Zero W, with Livebook remote access enabled via preset cookie.

## Preset Cookie for Demo

**Cookie Value:** `gassensor_demo_cookie_2024`  
**Node Name:** `sampler@nerves.local`  
**Purpose:** Livebook remote connection for monitoring/debugging

## Application Checklist

### ✅ gas_sensor (Business Logic)
- **OTP App:** Yes (`mod: {GasSensor.Application, []}`)
- **Starts:** ReadingAgent + Sensor GenServer
- **Hardware Access:** I2C bus only (no web code)
- **Config:** I2C bus from `config/target.exs`

### ✅ gas_sensor_web (Phoenix Web Interface)
- **OTP App:** Yes (`mod: {GasSensorWeb.Application, []}`)
- **Starts:** Telemetry + PubSub + Endpoint (port 80)
- **Hardware Access:** None (reads from Agent only)
- **Config:** Web port from `config/prod.exs`

### ✅ sampler (Nerves Firmware Container)
- **OTP App:** Yes (`mod: {Sampler.Application, []}`)
- **Starts:** Minimal supervision only
- **Dependencies:** Both gas_sensor and gas_sensor_web
- **Target:** rpi0 only
- **Cookie:** Preset for Livebook demo access

## Build & Deploy Instructions

### Quick Build

```bash
cd ~/elixir/genserver_gas_sampler
./build.sh
```

Or manually:

```bash
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

## What Gets Started on Boot

**Automatic OTP Application Startup Order:**

1. **gas_sensor** (via dependency)
   - ReadingAgent starts (data cache)
   - Sensor GenServer starts (I2C reading begins)
   - **I2C exclusive access** - only this process touches hardware

2. **gas_sensor_web** (via dependency)
   - Phoenix PubSub starts
   - Web server starts on port 80
   - **Reads from Agent only** - no I2C contention

3. **sampler** (main app)
   - Supervision coordination
   - **Distribution enabled** (Livebook connection ready)

4. **Erlang Distribution**
   - EPMD starts on port 4369
   - Node registered as `sampler@nerves.local`
   - Cookie set to `gassensor_demo_cookie_2024`

## Verification After Boot

### Check All Apps Running

Connect via serial or SSH, then in IEx:

```elixir
# List all running OTP applications
Application.started_applications() |> Enum.map(&elem(&1, 0))
# Expected: [:gas_sensor, :gas_sensor_web, :sampler, :nerves_runtime, ...]

# Check sensor is reading I2C
GasSensor.Sensor.get_state()
# Expected: %{i2c: #Reference<...>, ppm: 45.2, window: [...], status: :ok}

# Check Agent has data
GasSensor.ReadingAgent.get_reading()
# Expected: %{ppm: 45.2, window: [...], timestamp: ~U[...], status: :ok}

# Check web server running
:ets.tab2list(GasSensorWeb.Endpoint)
# Should show endpoint configuration

# Check distribution is ready (for Livebook)
Node.self()
# Expected: :"sampler@nerves.local"
Node.get_cookie()
# Expected: :gassensor_demo_cookie_2024

# Check EPMD is running
cmd("epmd -names")
# Expected: Shows sampler node at port XXXXX
```

### Check Web Interface

1. **Find Pi IP address:**
   ```elixir
   VintageNet.info()
   # or
   :inet.getifaddrs()
   ```

2. **Open browser:**
   - Dashboard: `http://<pi-ip>/`
   - Detailed view: `http://<pi-ip>/sensor`
   - API: `http://<pi-ip>/api/readings/current`

### Connect via Livebook (Optional)

See `LIVEBOOK_CONNECTION.md` for detailed instructions.

**Quick connect:**
```elixir
# In Livebook on your laptop
Node.start(:"livebook@YOUR_LAPTOP_IP", :shortnames)
Node.set_cookie(:"gassensor_demo_cookie_2024")
Node.connect(:"sampler@PI_ZERO_IP")

# Execute remotely
:rpc.call(:"sampler@PI_ZERO_IP", GasSensor.ReadingAgent, :get_ppm, [])
```

## Success Criteria

After booting Pi Zero W with your SD card:

✅ **Green LED blinks** (disk activity)  
✅ **All 3 OTP apps in `Application.started_applications()`**  
✅ **I2C sensor reading values**  
✅ **Agent has timestamped data**  
✅ **Web interface accessible at `http://<pi-ip>/`**  
✅ **PPM values updating every second**  
✅ **Distribution ready** (`Node.self()` returns sampler node)  

## Troubleshooting

### Apps not starting

```elixir
# Check if apps are loaded
Application.loaded_applications()

# Check for crashes
Process.whereis(GasSensor.Sensor)
Process.whereis(GasSensor.ReadingAgent)
Process.whereis(GasSensorWeb.Endpoint)
```

### Sensor not reading

```elixir
# Check I2C
case Circuits.I2C.open("i2c-1") do
  {:ok, ref} -> 
    Circuits.I2C.detect(ref)
    Circuits.I2C.close(ref)
  {:error, reason} -> 
    IO.inspect(reason)
end
```

### Web not accessible

```elixir
# Check network
VintageNet.info()

# Check if endpoint bound to port
:gen_tcp.connect('localhost', 80, [], 1000)
```

### Cannot connect via Livebook

```elixir
# On Pi - check distribution
Node.self()
# Should return :"sampler@nerves.local"
Node.get_cookie()
# Should return :gassensor_demo_cookie_2024

# Check EPMD
cmd("epmd -names")
# Should show sampler node registered

# Test local connection first
cmd("ping -c 1 192.168.1.45")
```

## Security Note for Production

**Current Configuration (Demo):**
- Fixed cookie: `gassensor_demo_cookie_2024`
- Easy to remember and share
- Suitable for demos and development

**For Production:**
```bash
# Generate secure random cookie
cookie=$(openssl rand -base64 32)

# Build with secure cookie
ERL_COOKIE="$cookie" mix firmware

# Never commit the cookie to git!
# Add to .gitignore: rel/vm.args.eex (if containing secrets)
```

## Files Updated

- ✅ `sampler/mix.exs` - Preset cookie configured
- ✅ `sampler/rel/vm.args.eex` - Distribution enabled
- ✅ `LIVEBOOK_CONNECTION.md` - Complete connection guide

## Next Steps

1. **Build firmware:** `./build.sh`
2. **Burn SD card:** `mix burn`
3. **Boot Pi Zero:** Insert SD, power on
4. **Configure WiFi:** Via IEx (see BUILD_AND_DEPLOY.md)
5. **Access web UI:** `http://<pi-ip>/`
6. **(Optional) Connect Livebook:** For remote monitoring

## Documentation Available

- `README.md` - Project overview
- `BUILD_AND_DEPLOY.md` - Complete build/deploy guide
- `ARCHITECTURE.md` - System architecture
- `MEMORY_ANALYSIS.md` - Memory optimization details
- `VM_OPTIMIZATION_GUIDE.md` - VM args deep dive
- `LIVEBOOK_CONNECTION.md` - Remote debugging/monitoring (NEW!)
- `FINAL_CHECKLIST.md` - This file

**Demo Cookie:** `gassensor_demo_cookie_2024`  
**Ready to build and connect!** 🚀
