# NTP Server Configuration Guide

## Overview

The Gas Sensor project uses **Nerves Time** (`nerves_time`) to synchronize the system clock on Raspberry Pi Zero W. By default, it uses the public NTP pool, but you can configure custom NTP servers.

**Why Configure Custom NTP Servers?**
- 🏢 **Corporate networks** - Internal NTP servers required
- 🌏 **Regional optimization** - Use closer servers for faster sync
- 🔒 **Security** - Private NTP infrastructure
- 🚫 **Pool blocked** - Some networks block public NTP pools
- ⚡ **Reliability** - Redundant custom servers

---

## Quick Configuration

### Where to Configure

**File:** `sampler/config/target.exs`

**Configuration Section:**
```elixir
config :nerves_time, :servers, [
  # Your custom NTP servers here
  "ntp.mycompany.com",
  "192.168.1.1",
  "0.pool.ntp.org"  # Fallback to public pool
]
```

---

## Configuration Options

### Option 1: Public NTP Pool (Default)

**Recommended for:** Home use, small networks, general deployment

```elixir
config :nerves_time, :servers, [
  "0.pool.ntp.org",
  "1.pool.ntp.org", 
  "2.pool.ntp.org",
  "3.pool.ntp.org"
]
```

**Pros:**
- ✅ Automatically load-balanced
- ✅ Thousands of servers worldwide
- ✅ Highly reliable
- ✅ Free to use

**Cons:**
- ❌ Requires internet access
- ❌ May be blocked by corporate firewalls
- ❌ Slower sync from some regions

---

### Option 2: Regional Pool Servers

**Recommended for:** Better performance in specific regions

#### North America
```elixir
config :nerves_time, :servers, [
  "0.north-america.pool.ntp.org",
  "1.north-america.pool.ntp.org",
  "2.north-america.pool.ntp.org"
]
```

#### Europe
```elixir
config :nerves_time, :servers, [
  "0.europe.pool.ntp.org",
  "1.europe.pool.ntp.org",
  "2.europe.pool.ntp.org"
]
```

#### Asia
```elixir
config :nerves_time, :servers, [
  "0.asia.pool.ntp.org",
  "1.asia.pool.ntp.org",
  "2.asia.pool.ntp.org"
]
```

#### Other Regions
- `0.oceania.pool.ntp.org` - Australia, NZ, Pacific
- `0.africa.pool.ntp.org` - Africa
- `0.south-america.pool.ntp.org` - South America

**Pros:**
- ✅ Lower latency
- ✅ Faster synchronization
- ✅ Reduced bandwidth

---

### Option 3: Corporate/Internal NTP Servers

**Recommended for:** Enterprise networks, security-focused deployments

```elixir
config :nerves_time, :servers, [
  # Primary internal server
  "ntp.company.com",
  
  # Backup internal server
  "ntp-backup.company.com",
  
  # Local router (if it provides NTP)
  "192.168.1.1",
  
  # Fallback to public pool (optional)
  "0.pool.ntp.org"
]
```

**Pros:**
- ✅ Works without internet
- ✅ Controlled by your IT department
- ✅ Better security
- ✅ Auditable

**Cons:**
- ❌ Requires internal NTP infrastructure
- ❌ Must maintain server uptime

---

### Option 4: Router/Gateway NTP

**Recommended for:** Simple home/small office setups

```elixir
config :nerves_time, :servers, [
  # Use local router as NTP source
  "192.168.1.1",    # Common router IP
  "10.0.0.1",       # Alternative router IP
  
  # Fallback to public pool
  "0.pool.ntp.org"
]
```

**Setup on Router:**
Most consumer routers can provide NTP:
1. Log into router admin panel
2. Find "Time Settings" or "NTP"
3. Enable "NTP Server" or "Provide NTP to LAN"
4. Set Pi to use router IP

**Pros:**
- ✅ Very fast (same network)
- ✅ No internet required for local time
- ✅ Router syncs to internet periodically

**Cons:**
- ❌ If router loses time, all devices drift

---

### Option 5: GPS-based NTP (High Precision)

**Recommended for:** Research, precision applications, offline operation

```elixir
config :nerves_time, :servers, [
  # GPS module provides time directly
  # (No network NTP needed)
]
```

**Hardware Required:**
- GPS module with PPS (Pulse Per Second) output
- Examples: u-blox NEO-6M, Adafruit Ultimate GPS

**Software:**
Use `nerves_time_rtc` with GPS receiver:

```elixir
# In config/target.exs
config :nerves_time, :rtc, NervesTime.RTC.ABSim

# Or use GPS-specific library
config :nerves_time, :rtc, MyApp.GPSRTC
```

**Pros:**
- ✅ Extremely accurate (< 1 microsecond)
- ✅ No internet required
- ✅ Works anywhere (mountains, ships, remote sites)

**Cons:**
- ❌ Requires GPS hardware ($20-50)
- ❌ Needs GPS signal (won't work indoors)
- ❌ Complex setup

---

## Configuration Examples

### Example 1: Home Network (Simple)

```elixir
# sampler/config/target.exs

# Use default pool - works for 99% of home users
config :nerves_time, :servers, [
  "0.pool.ntp.org",
  "1.pool.ntp.org"
]
```

### Example 2: Office with Restricted Internet

```elixir
# sampler/config/target.exs

config :nerves_time, :servers, [
  # Company internal NTP
  "time.mycompany.com",
  "time-backup.mycompany.com",
  
  # Local router as last resort
  "192.168.1.254"
]
```

### Example 3: Multi-Site Enterprise

```elixir
# sampler/config/target.exs

config :nerves_time, :servers, [
  # Site-specific NTP servers
  "ntp-site1.company.com",
  "ntp-site2.company.com",
  "ntp-site3.company.com",
  
  # Regional pool as backup
  "0.europe.pool.ntp.org"
]
```

### Example 4: Mobile/Changing Networks

```elixir
# sampler/config/target.exs

config :nerves_time, :servers, [
  # Multiple options for different networks
  "192.168.1.1",    # Home router
  "10.0.0.1",       # Office router  
  "172.16.0.1",     # Mobile hotspot
  "0.pool.ntp.org"  # Public fallback
]
```

### Example 5: Offline Operation (No NTP)

```elixir
# sampler/config/target.exs

# Empty list - no NTP servers
# System will use build date + monotonic time
config :nerves_time, :servers, []

# Consider adding external RTC hardware
# See RTC_HANDLING.md for details
```

**Warning:** Without NTP, timestamps will be provisional (build date + uptime). See `WIFI_OFFLINE_MODE.md`.

---

## Advanced Configuration

### Sync Interval

How often to sync with NTP servers:

```elixir
# sampler/config/target.exs

# Sync every 11 minutes (default)
config :nerves_time, :sync_interval, 660  # seconds

# Sync every hour (less network traffic)
config :nerves_time, :sync_interval, 3600

# Sync every 5 minutes (more accurate)
config :nerves_time, :sync_interval, 300
```

**Recommendations:**
- **Normal use:** 11 minutes (default) ✅
- **Poor connectivity:** 1 hour (reduces network load)
- **High precision needed:** 5 minutes (keeps clock tight)

### Sync Timeout

How long to wait for NTP response:

```elixir
# sampler/config/target.exs

config :nerves_time, :sync_timeout, 30_000  # 30 seconds (default)

# Increase for slow networks
config :nerves_time, :sync_timeout, 60_000  # 60 seconds
```

---

## Testing Your Configuration

### Step 1: Check Current NTP Servers

```bash
# On the Pi via IEx
NervesTime.servers()
# Returns list of configured servers
```

### Step 2: Check Sync Status

```elixir
# Check if time is synchronized
NervesTime.synchronized?()
# true = synced with NTP
# false = not yet synced

# Get detailed status
NervesTime.status()
# %{
#   synchronized: true,
#   rtc_available: false,
#   last_sync: ~U[2024-03-30 14:25:18Z],
#   next_sync: ~U[2024-03-30 14:36:18Z]
# }
```

### Step 3: Force Sync

```elixir
# Manually trigger NTP sync
NervesTime.sync()

# Or restart nerves_time to re-read config
NervesTime.restart()
```

### Step 4: Check Network Connectivity

```elixir
# Test if NTP servers are reachable
:os.cmd('ping -c 1 0.pool.ntp.org')

# Or use VintageNet
VintageNet.info()
```

---

## Troubleshooting

### Problem: "Time not syncing"

**Symptoms:**
```elixir
NervesTime.synchronized?()
# false (even after minutes)
```

**Causes & Solutions:**

1. **No internet connection**
   ```elixir
   # Check WiFi
   VintageNet.info()
   # Should show wlan0 connected
   ```

2. **NTP servers unreachable**
   ```bash
   # Test connectivity
   ping 0.pool.ntp.org
   ```

3. **NTP servers blocked by firewall**
   - Try using internal NTP server
   - Use router as NTP source
   - Open port 123 (NTP) on firewall

4. **Incorrect NTP server addresses**
   ```elixir
   # Verify servers list
   Application.get_env(:nerves_time, :servers)
   ```

### Problem: "Time syncs but drifts"

**Symptoms:** Time accurate after boot, but slowly becomes wrong

**Causes:**
- NTP sync interval too long
- System under heavy load
- Network unreliable

**Solutions:**
```elixir
# Shorten sync interval
config :nerves_time, :sync_interval, 300  # Every 5 minutes
```

### Problem: "Time jumps around"

**Symptoms:** Time corrects then jumps back

**Causes:**
- Multiple NTP servers with different times
- Unreliable network connection
- Server has wrong time

**Solutions:**
```elixir
# Use fewer, more reliable servers
config :nerves_time, :servers, [
  "time.google.com",  # Google NTP (very reliable)
  "0.pool.ntp.org"    # Fallback
]
```

### Problem: "NTP blocked on corporate network"

**Symptoms:** All NTP syncs fail, time stays at epoch

**Solutions:**

1. **Use internal NTP server:**
   ```elixir
   config :nerves_time, :servers, [
     "ntp.mycompany.com",
     "192.168.1.1"
   ]
   ```

2. **Use router as NTP:**
   - Configure router to provide NTP
   - Point Pi to router

3. **HTTP-based time sync (alternative):**
   ```elixir
   # Use HTTP headers instead of NTP
   # Requires custom implementation
   ```

---

## Best Practices

### DO:
- ✅ Use at least 2-3 NTP servers (redundancy)
- ✅ Mix internal and external servers
- ✅ Use regional pool servers for better performance
- ✅ Test NTP connectivity before deployment
- ✅ Monitor time sync status in production

### DON'T:
- ❌ Use only one NTP server (single point of failure)
- ❌ Use `time.windows.com` (Microsoft, may be blocked)
- ❌ Sync more often than every 5 minutes (unnecessary network load)
- ❌ Use public servers for high-precision applications (use GPS instead)

---

## Enterprise Considerations

### Security Requirements

**If your company requires:**
- Time sync without internet → Use internal NTP
- Auditable time sources → Use company-controlled NTP
- Secure time sync → Use NTP with authentication (NTS)

**NTS (Network Time Security):**
```elixir
# Currently nerves_time doesn't support NTS
# For secure NTP, use internal trusted servers
config :nerves_time, :servers, [
  "ntp-internal.company.com"
]
```

### Compliance

**For regulated industries (healthcare, finance, etc.):**
- Document your NTP sources
- Maintain NTP server uptime
- Log time synchronization events
- Use redundant time sources

**Example compliance setup:**
```elixir
config :nerves_time, :servers, [
  "ntp-primary.compliance.company.com",
  "ntp-secondary.compliance.company.com",
  "ntp-tertiary.compliance.company.com"
]

# Short sync interval for accuracy
config :nerves_time, :sync_interval, 300
```

---

## Monitoring

### Add to IEx Helpers

```elixir
# In sampler/rootfs_overlay/etc/iex.exs

defmodule Sampler.TimeHelpers do
  @doc "Check NTP sync status"
  def ntp_status do
    case NervesTime.synchronized?() do
      true -> 
        IO.puts("✅ Time synchronized with NTP")
        NervesTime.status() |> IO.inspect()
      false ->
        IO.puts("⚠️ Time NOT synchronized")
        IO.puts("Servers: #{inspect(NervesTime.servers())}")
        IO.puts("Check WiFi: VintageNet.info()")
    end
  end
  
  @doc "Force NTP sync"
  def force_sync do
    IO.puts("Forcing NTP sync...")
    NervesTime.sync()
    :timer.sleep(5000)
    ntp_status()
  end
end
```

---

## Quick Reference

### Common NTP Servers

| Server | Type | Best For |
|--------|------|----------|
| `0.pool.ntp.org` | Public pool | General use |
| `time.google.com` | Google | Reliability |
| `time.apple.com` | Apple | macOS environments |
| `time.cloudflare.com` | Cloudflare | Speed |
| `ntp.ubuntu.com` | Ubuntu | Linux environments |

### Configuration Checklist

- [ ] Choose appropriate NTP servers for your network
- [ ] Add 2-4 servers (redundancy)
- [ ] Test connectivity to servers
- [ ] Configure in `sampler/config/target.exs`
- [ ] Rebuild firmware
- [ ] Test on device
- [ ] Monitor sync status

---

## Summary

**You have full control over NTP configuration!**

- Default: Public NTP pool (works everywhere)
- Corporate: Internal NTP servers
- Regional: Geographic-specific pools
- Secure: Private infrastructure
- Offline: No NTP (provisional timestamps)

**File to edit:** `sampler/config/target.exs`  
**Key setting:** `config :nerves_time, :servers, [...]`  
**Rebuild required:** Yes (`./build.sh`)

**Status:** ✅ Fully configurable!
