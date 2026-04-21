# WiFi Offline Mode - Handling No Network Connection

## The Problem

**Raspberry Pi Zero W + No WiFi = Wrong Timestamps**

```
Scenario 1: WiFi Available
├─ Boot → 1970-01-01
├─ WiFi connects → Network up
├─ NTP syncs → Time jumps to 2024-03-30 10:15:00
└─ All timestamps accurate ✅

Scenario 2: No WiFi / Router Down
├─ Boot → 1970-01-01
├─ WiFi fails → No network
├─ NTP cannot sync → Time stays at 1970 or build date
└─ All timestamps WRONG ❌
```

## Our Solution

### What Happens When WiFi is Unavailable

**1. Detection**
```elixir
GasSensor.Timestamp.now_with_reliability()
# Returns: {timestamp, false}  ← reliable? = false

# System detects year < 2020 (indicates epoch/build date)
# Logs warning (throttled to once per 30 seconds)
# Enters "offline mode"
```

**2. Provisional Timestamps**

Instead of storing 1970 timestamps, we create provisional timestamps:

```elixir
# Formula: firmware_build_date + monotonic_time_offset

T+0s:  provisional_timestamp() → ~U[2024-03-30 12:00:00Z]  ← Start
T+5s:  provisional_timestamp() → ~U[2024-03-30 12:00:05Z]  ← +5 seconds
T+10s: provisional_timestamp() → ~U[2024-03-30 12:00:10Z]  ← +10 seconds
```

**Benefits:**
- ✅ Timestamps in 2024s (not 1970s) - looks reasonable
- ✅ Unique (no collisions)
- ✅ Chronologically ordered (monotonic offset)
- ✅ Marked as `time_reliable: false`

**3. Warning Throttling**

Instead of logging "Time unsynced" every sample (60+ warnings/minute):

```
T+0s:   WARNING: Operating in offline mode - timestamps provisional
T+30s:  (no warning - throttled)
T+60s:  (no warning - throttled)
T+90s:  WARNING: Operating in offline mode - timestamps provisional
```

### What Data Looks Like

**Offline Readings:**
```elixir
%{
  ppm: 45.2,
  timestamp: ~U[2024-03-30 12:05:42Z],  # Provisional (build date + offset)
  time_reliable: false,                    # ⚠️ Flagged as unreliable
  status: :ok
}
```

**Synced Readings (after WiFi reconnects):**
```elixir
%{
  ppm: 47.1,
  timestamp: ~U[2024-03-30 14:26:18Z],  # Accurate NTP time
  time_reliable: true,                    # ✅ Reliable
  status: :ok
}
```

## When WiFi Reconnects

### Time Jump Handling

```
T+0s to T+300s: No WiFi (5 minutes offline)
  ├─ Samples stored with provisional timestamps
  ├─ e.g., 12:00:00, 12:00:05, 12:00:10...
  └─ All marked time_reliable: false

T+301s: WiFi connects
  ├─ NTP starts syncing
  └─ System time: still 12:05:00 (provisional)

T+360s: NTP sync complete
  ├─ System time jumps: 12:05:00 → 14:30:00 (+2.5 hours)
  ├─ New samples get accurate timestamps
  └─ Log: "Time synchronization recovered!"
```

### Result in History

```
History Table:
├─ [12:00:00] Sample 1 (provisional, offline)
├─ [12:00:05] Sample 2 (provisional, offline)
├─ [12:00:10] Sample 3 (provisional, offline)
├─ ... (5 minutes of offline data)
├─ [14:30:00] Sample N (accurate, online)     ← Time jump
└─ [14:30:05] Sample N+1 (accurate, online)
```

**Important:** There's a **time gap** in the history (12:05 to 14:30)
This is expected and indicates the offline period.

## Configuration

### Firmware Build Date

**File:** `gas_sensor/config/target.exs`

```elixir
config :gas_sensor,
  i2c_bus: "i2c-1",
  # UPDATE THIS when rebuilding firmware:
  firmware_build_date: ~U[2024-03-30 00:00:00Z]
```

**Why this matters:**
- Offline timestamps are relative to this date
- Should be close to actual firmware build date
- 30-day old firmware + offline = 30-day old timestamps (still better than 1970)

### Update Build Date When Rebuilding

```bash
# Before building firmware:
# 1. Edit config/target.exs
# 2. Update firmware_build_date to today
# 3. Then build:

./build.sh
```

## API for Checking Status

### In IEx (on Pi)

```elixir
# Check current time status
GasSensor.Timestamp.status()
# Returns:
# %{
#   current_time: ~U[2024-03-30 12:05:42Z],
#   reliable: false,                    ← ⚠️ Not synced
#   offline_mode: true,                 ← 📵 In offline mode
#   year: 2024,
#   provisional_time: ~U[2024-03-30 12:05:42Z],
#   warning: "Offline mode: WiFi/NTP unavailable..."
# }

# Check if NTP synced
GasSensor.Timestamp.ntp_synced?()
# false (offline) or true (synced)

# Check if in offline mode
GasSensor.Timestamp.offline_mode?()
# true or false

# Check reading reliability
GasSensor.ReadingAgent.time_reliable?()
# false = using provisional timestamps
```

### In Web Dashboard

Updated dashboard shows offline status:

```html
<!-- When offline -->
<div class="bg-yellow-100 p-4 rounded">
  ⚠️ Offline Mode - WiFi unavailable
  <p>Timestamps are provisional (relative to boot time)</p>
  <p>Connect to WiFi for accurate timestamps</p>
</div>

<!-- When synced -->
<div class="bg-green-100 p-4 rounded">
  ✅ Time synchronized
  <p>All timestamps accurate</p>
</div>
```

## Impact on 24-Hour History

### Offline Scenarios

**Scenario A: Brief outage (5-10 minutes)**
```
Data:        Continuous
Timestamps:  Mostly accurate, 5-10 min provisional
Graph:       Shows gap or uses provisional times
Impact:      Minimal - data still useful
```

**Scenario B: Long outage (hours)**
```
Data:        Continuous
Timestamps:  Hours of provisional data
Graph:       Large time jump when reconnect
Impact:      Historical ordering preserved, but absolute times wrong
```

**Scenario C: Never connects (always offline)**
```
Data:        Continuous
Timestamps:  All provisional (build date + uptime)
Graph:       Looks like all data from "today"
Impact:      Cannot do accurate long-term trending
```

### Recommendations

**For home monitoring:**
- ✅ Brief outages acceptable - provisional timestamps are fine
- ✅ Data continuity more important than perfect timestamps
- ✅ Historical patterns still visible (daily cycles, etc.)

**For research/compliance:**
- ⚠️ Consider adding external RTC hardware (DS3231)
- ⚠️ Monitor WiFi connectivity
- ⚠️ Flag provisional data in analysis

## Code Example: Handling Offline Data

```elixir
# Get all samples
samples = GasSensor.History.get_last_24h()

# Filter to only reliable (synced) data
reliable_samples = Enum.filter(samples, & &1.time_reliable)

# Show warning if too much offline data
offline_count = length(samples) - length(reliable_samples)
if offline_count > 100 do
  IO.puts("⚠️ #{offline_count} samples have provisional timestamps")
  IO.puts("Consider checking WiFi connectivity")
end

# For graphing: use all data but mark unreliable points
VegaLite.new()
|> VegaLite.data_from_values(samples)
|> VegaLite.encode_field(:color, :time_reliable,
    scale: [domain: [true, false], range: ["blue", "gray"]]
  )
# Blue = reliable, Gray = provisional
```

## Troubleshooting

### Symptom: All timestamps show same time

**Cause:** System using build date but monotonic counter not advancing (rare)

**Check:**
```elixir
# Should increase every call
GasSensor.Timestamp.monotonic_ms()
```

**Fix:** Restart the application

### Symptom: Timestamps jump backwards

**Cause:** Very rare - time sync during provisional timestamp generation

**Check logs:**
```elixir
RingLogger.next
# Look for "Time synchronization recovered!"
```

**Normal behavior:** New samples will have correct time, old samples keep provisional

### Symptom: History cleanup not working

**Cause:** 24h window calculated from current time (if offline for >24h, all data appears "recent")

**Impact:** When time syncs, may delete all "old" (provisional) data at once

**Mitigation:** This is expected - the data was from offline period anyway

## Comparison with Alternatives

### Our Approach vs Other Solutions

| Approach | Offline Timestamps | Memory | CPU | Accuracy | Verdict |
|----------|-------------------|--------|-----|----------|---------|
| **Provisional (Ours)** | Build date + offset | 0 KB | Low | Relative ✅ | **Best** |
| Pure 1970 epoch | 1970-01-01 + offset | 0 KB | Low | Wrong ❌ | Looks broken |
| Skip offline data | None stored | 0 KB | Low | No data ❌ | Data loss |
| External RTC | Accurate | 0 KB | None | Perfect ✅ | Extra hardware |
| GPS module | Accurate | 0 KB | Medium | Perfect ✅ | Expensive |

**Our choice:** Provisional timestamps preserve data continuity while clearly marking it as unreliable.

## Quick Reference

```elixir
# Check WiFi/time status
GasSensor.Timestamp.status()

# Check if offline
GasSensor.Timestamp.offline_mode?()

# Get provisional timestamp (for manual use)
GasSensor.Timestamp.provisional_timestamp()

# Filter reliable data
Enum.filter(samples, & &1.time_reliable)

# In dashboard template
<%= if @reading.time_reliable do %>
  ✅ Time synced
<% else %>
  ⚠️ Offline mode - timestamps provisional
<% end %>
```

## Bottom Line

**When WiFi is unavailable:**
- ✅ Data still collected (no gaps)
- ✅ Timestamps use build date + monotonic offset (2024, not 1970)
- ✅ Relative ordering preserved (5s, 10s, 15s intervals correct)
- ✅ Flagged as `time_reliable: false`
- ✅ Warning logged (throttled, not spam)

**When WiFi reconnects:**
- ✅ New samples get accurate timestamps
- ✅ Log message indicates recovery
- ✅ Old provisional data stays in history
- ✅ Time jump visible in graphs (expected)

**For Pi Zero W without RTC + unreliable WiFi:**
- ⚠️ Accept that some data will have provisional timestamps
- ✅ Prioritize data continuity over timestamp perfection
- ✅ Monitor `time_reliable` flag in analysis
- ✅ Consider external RTC for mission-critical applications

**The system is designed to work even without WiFi - you won't lose sensor data!**
