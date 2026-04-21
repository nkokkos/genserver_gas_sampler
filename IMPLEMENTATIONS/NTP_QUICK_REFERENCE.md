# NTP Server Configuration - Quick Summary

## ✅ YES - You Can Configure Custom NTP Servers!

The NTP server configuration is fully customizable through module attributes and settings.

---

## **Where to Configure**

**File:** `sampler/config/target.exs`

**Configuration:**
```elixir
config :nerves_time, :servers, [
  # Add your custom NTP servers here
  "ntp.mycompany.com",
  "192.168.1.1",
  "time.google.com",
  "0.pool.ntp.org"
]
```

---

## **Example Configurations**

### 1. Public NTP Pool (Default)
```elixir
config :nerves_time, :servers, [
  "0.pool.ntp.org",
  "1.pool.ntp.org",
  "2.pool.ntp.org"
]
```

### 2. Corporate/Internal Servers
```elixir
config :nerves_time, :servers, [
  "ntp.company.com",
  "ntp-backup.company.com",
  "192.168.1.1"  # Router
]
```

### 3. Regional Servers (Better Performance)
```elixir
# Europe
config :nerves_time, :servers, [
  "0.europe.pool.ntp.org",
  "1.europe.pool.ntp.org"
]

# North America
config :nerves_time, :servers, [
  "0.north-america.pool.ntp.org",
  "1.north-america.pool.ntp.org"
]
```

### 4. Mixed (Best Practice)
```elixir
config :nerves_time, :servers, [
  # Primary: Internal company server
  "ntp.mycompany.com",
  
  # Backup: Local router
  "192.168.1.1",
  
  # Fallback: Public pool
  "0.pool.ntp.org"
]
```

---

## **Advanced Options**

### Sync Interval
```elixir
# How often to sync (seconds)
config :nerves_time, :sync_interval, 660  # 11 minutes (default)
# config :nerves_time, :sync_interval, 300  # 5 minutes (more accurate)
# config :nerves_time, :sync_interval, 3600 # 1 hour (less network)
```

---

## **How to Apply**

```bash
# 1. Edit the configuration
nano sampler/config/target.exs

# 2. Rebuild firmware
./build.sh

# 3. Burn to SD card
cd sampler && mix burn

# 4. Test on Pi
# In IEx:
NervesTime.servers()  # Check configured servers
NervesTime.synchronized?()  # Check sync status
```

---

## **Verification Commands**

```elixir
# Check configured servers
NervesTime.servers()
# ["ntp.mycompany.com", "192.168.1.1", "0.pool.ntp.org"]

# Check sync status
NervesTime.synchronized?()
# true or false

# Force sync
NervesTime.sync()

# Get full status
NervesTime.status()
# %{synchronized: true, last_sync: ~U[...], next_sync: ~U[...]}
```

---

## **Common Use Cases**

| Use Case | Recommended Servers |
|----------|-------------------|
| **Home use** | `0.pool.ntp.org` |
| **Office (internet)** | `time.google.com`, `0.pool.ntp.org` |
| **Office (no internet)** | `192.168.1.1` (router) |
| **Corporate** | `ntp.company.com`, `192.168.1.1` |
| **High precision** | GPS module (hardware) |

---

## **Files Modified**

1. ✅ `sampler/config/target.exs` - Added NTP configuration section
2. ✅ `NTP_CONFIGURATION.md` - Complete configuration guide

---

## **Key Points**

- ✅ **Fully configurable** - Any NTP server you want
- ✅ **Multiple servers** - Add redundancy (2-4 recommended)
- ✅ **Mix types** - Internal + external + router
- ✅ **Regional pools** - Better performance
- ✅ **Rebuild required** - After changing config
- ✅ **Runtime check** - `NervesTime.servers()` to verify

---

## **Need More Info?**

**Full documentation:** `NTP_CONFIGURATION.md`

Covers:
- All configuration options
- Corporate network setups
- Regional server selection
- Troubleshooting
- Best practices
- Security considerations

---

**Status:** ✅ NTP servers fully configurable!  
**Implementation:** Already in `sampler/config/target.exs`  
**Ready to use:** Just edit and rebuild!
