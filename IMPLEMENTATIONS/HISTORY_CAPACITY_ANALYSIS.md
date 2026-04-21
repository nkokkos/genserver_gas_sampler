# History Storage Capacity Analysis for Raspberry Pi Zero W

## Executive Summary

**Safe Recommendation:** Up to **90 days** of history storage (~1.35MB)  
**Theoretical Maximum:** Up to **18 years** of history (~100MB)  
**Practical Sweet Spot:** **7-30 days** (~105KB-450KB)

---

## System Resources

### Pi Zero W Memory Budget

```
Total RAM:                    512 MB
├── Linux Kernel:            ~50-80 MB (OS overhead)
├── System/Caches:            ~50-100 MB (buffers, etc.)
├── Available for BEAM VM:    ~300-350 MB
│   └── Current Application:
│       ├── gas_sensor:       ~5-10 MB
│       │   └── History:      ~900 KB (24h = 17,280 samples)
│       ├── gas_sensor_web:   ~40-60 MB
│       ├── sampler:          ~1-2 MB
│       ├── Dependencies:     ~30-40 MB
│       └── VM Overhead:      ~20-30 MB
│       └── TOTAL NOW:        ~100-150 MB
├── RECOMMENDED SAFETY:       ~50-100 MB (for peak loads, GC)
└── AVAILABLE FOR HISTORY:    ~100-150 MB
```

### Current Utilization

```
Used:           ~100-150 MB
Available:      ~300 MB
Safety Reserve: ~50 MB
Can Allocate:   ~50-150 MB for extended history
```

---

## Per-Sample Memory Calculation

### Data Structure Size

```elixir
# Each history entry: {timestamp, ppm, status}

%{timestamp: DateTime, ppm: float, status: atom}

Memory breakdown per sample:
├── Map overhead:            ~32 bytes
├── Timestamp (DateTime):    ~40 bytes
│   ├── DateTime struct:    ~24 bytes
│   └── Calendar data:       ~16 bytes
├── PPM (float):            ~16 bytes (IEEE 754 double)
├── Status (atom):           ~8 bytes (atom reference)
├── ETS overhead:            ~4 bytes
└── TOTAL:                  ~52-56 bytes per sample

Conservative estimate:        60 bytes per sample
```

### Sampling Rate

```
Current sampling:
├── 7 samples / 5 seconds = 12 samples/minute
├── 12 samples/hour
├── 288 samples/day
└── 17,280 samples/week

Alternative sampling (if needed):
├── Every 5 seconds = 720 samples/hour
├── Every minute = 60 samples/hour
├── Every 5 minutes = 12 samples/hour (current)
```

---

## Capacity Scenarios

### Conservative Scenario (50 MB allocation)

```
Available:     50 MB = 52,428,800 bytes
Per sample:    60 bytes
Max samples:   52,428,800 / 60 = 873,813 samples

At current rate (12 samples/hour):
└── 873,813 / 12 = 72,818 hours = 3,034 days = ~8.3 YEARS

At higher rate (60 samples/hour):
└── 873,813 / 60 = 14,564 hours = 607 days = ~1.7 YEARS
```

### Aggressive Scenario (150 MB allocation)

```
Available:     150 MB = 157,286,400 bytes
Max samples:   157,286,400 / 60 = 2,621,440 samples

At current rate:
└── 2,621,440 / 12 = 218,453 hours = 9,102 days = ~25 YEARS
```

### What About ETS Overhead?

```
ETS tables have overhead per entry:
├── Table header:          ~1 KB (fixed, one-time)
├── Per-bucket overhead:   ~8 bytes (amortized)
├── Memory fragmentation:  ~10-15%
└── Total overhead:        ~15-20%

Adjusted capacity with 20% overhead:
├── Conservative (50 MB):  ~6.6 years
├── Aggressive (150 MB):   ~20 years
```

---

## Practical Recommendations

### For Different Use Cases

#### 1. **Home Monitoring (Recommended)**
```
History:        7 days
Samples:        2,016 (12/hr × 24 × 7)
Memory:         ~120 KB
Use case:       Daily patterns, recent trends
Safety margin:  Massive ✅
Verdict:        Perfect for home use
```

#### 2. **Office/Commercial**
```
History:        30 days
Samples:        8,640 (12/hr × 24 × 30)
Memory:         ~520 KB
Use case:       Monthly reports, compliance
Safety margin:  Excellent ✅
Verdict:        Good for commercial monitoring
```

#### 3. **Research/Long-term Study**
```
History:        90 days
Samples:        25,920 (12/hr × 24 × 90)
Memory:         ~1.5 MB
Use case:       Seasonal patterns, studies
Safety margin:  Very good ✅
Verdict:        Suitable for research
```

#### 4. **Maximum Practical**
```
History:        365 days (1 year)
Samples:        105,120 (12/hr × 24 × 365)
Memory:         ~6.3 MB
Use case:       Annual trends, year-over-year
Safety margin:  Good ✅
Verdict:        Doable but monitor carefully
```

#### 5. **Ultra-Long (Not Recommended)**
```
History:        2+ years
Memory:         12+ MB
Risk:           Memory fragmentation over time
Maintenance:    Requires monitoring
Verdict:        Consider SQLite for persistent storage
```

---

## Implementation Options

### Option A: Fixed 7-Day Window (Current)
```elixir
@retention_seconds 604_800  # 7 days

Pros:
✅ Minimal memory (~120 KB)
✅ Fast queries
✅ Simple implementation
✅ Perfect for real-time dashboards

Cons:
❌ Can't see trends beyond 1 week
❌ No historical comparison
```

### Option B: Tiered Storage (Recommended Upgrade)
```
Layer 1: Recent Data (ETS - RAM)
├── 24 hours at full resolution (12 samples/hour)
├── ~17 KB
└── Fast access for dashboard

Layer 2: Medium-term (ETS - RAM)
├── 30 days at full resolution
├── ~520 KB
└── Good for monthly analysis

Layer 3: Long-term (Optional - Disk)
├── Daily averages only (1 sample/day)
├── 365 days = 365 samples
├── ~21 KB (or SQLite ~1 MB)
└── Year-over-year comparison

Total: ~540 KB + optional SQLite
```

### Option C: Downsampled Long-term (Advanced)
```
Recent (ETS):
├── 24 hours at full resolution: 288 samples
└── ~17 KB

Medium (ETS):
├── 7 days at full resolution: 2,016 samples
└── ~120 KB

Long-term (SQLite or file):
├── 365 days at 1-hour resolution: 8,760 samples
├── Store min/max/avg per hour
├── ~500 KB - 1 MB on disk
└── Minimal RAM usage

Total RAM: ~140 KB
```

---

## Monitoring Recommendations

### Add Memory Tracking

Add this to your IEx helpers:

```elixir
# In sampler/rootfs_overlay/etc/iex.exs

defmodule Sampler.Monitoring do
  @doc "Check history memory usage"
  def history_capacity do
    bytes = GasSensor.History.memory_usage()
    mb = bytes / 1024 / 1024
    count = GasSensor.History.size()
    
    %{
      samples: count,
      bytes: bytes,
      mb: Float.round(mb, 3),
      percentage_of_total: Float.round(mb / 512 * 100, 2),
      estimated_days: Float.round(count / 288, 1),  # At 12/hour
      status: if(mb < 10, do: :excellent, else: if(mb < 50, do: :good, else: :warning))
    }
  end
  
  @doc "Check if we can extend history"
  def can_extend_history?(target_days) do
    current = history_capacity()
    target_samples = target_days * 288  # 12/hour × 24h
    target_mb = target_samples * 60 / 1024 / 1024
    available_mb = 150  # Conservative
    
    %{
      can_extend: target_mb < available_mb,
      current_mb: current.mb,
      target_mb: Float.round(target_mb, 2),
      available_mb: available_mb,
      message: if(target_mb < available_mb, 
        do: "✅ Can extend to #{target_days} days", 
        else: "❌ Would exceed safe memory limit")
    }
  end
end
```

### Memory Alerts

Add to your Livebook monitoring:

```elixir
# Alert if history exceeds 10 MB
history_mb = GasSensor.History.memory_usage() / 1024 / 1024

if history_mb > 10 do
  IO.puts("⚠️ WARNING: History using #{Float.round(history_mb, 2)} MB")
  IO.puts("Consider reducing retention or switching to disk storage")
end
```

---

## Upgrade Path

### When to Expand History?

**Do expand to 30-90 days if:**
- ✅ Need weekly/monthly pattern analysis
- ✅ Commercial/compliance requirements
- ✅ Current memory usage < 50 MB total
- ✅ Not experiencing GC pressure

**Don't expand if:**
- ❌ Memory already tight (>200 MB used)
- ❌ Planning to add more features
- ❌ Need real-time processing of other data
- ❌ SD card frequently written (consider disk storage)

### How to Expand?

**Step 1: Change retention period**
```elixir
# In gas_sensor/lib/gas_sensor/history.ex
@retention_seconds 2_592_000  # 30 days (was 86_400 for 1 day)
```

**Step 2: Update dashboard refresh**
```elixir
# Reduce refresh rate for longer history
@history_refresh 30_000  # 30 seconds (was 5 seconds)
```

**Step 3: Monitor**
```elixir
# Watch memory for 24 hours
:erlang.memory()[:total] / 1024 / 1024
```

---

## Comparison with Alternative Storage

### ETS (Current) vs SQLite vs Files

| Duration | ETS (RAM) | SQLite (Disk) | Files (Disk) |
|----------|-----------|---------------|--------------|
| 1 day | 17 KB ✅ | 1 MB ❌ | 10 KB ✅ |
| 7 days | 120 KB ✅ | 1.5 MB ❌ | 70 KB ✅ |
| 30 days | 520 KB ✅ | 3 MB ❌ | 300 KB ✅ |
| 90 days | 1.5 MB ✅ | 8 MB ⚠️ | 900 KB ✅ |
| 1 year | 6 MB ✅ | 30 MB ⚠️ | 3.5 MB ✅ |
| 5 years | 30 MB ⚠️ | 150 MB ❌ | 18 MB ❌ |

**Legend:**
- ✅ Perfect fit for Pi Zero
- ⚠️ Doable but monitor closely
- ❌ Not recommended (risky)

### Recommendation by Duration

- **1-90 days:** ETS in RAM (fast, simple)
- **90-365 days:** SQLite on disk (persistent, queryable)
- **1+ years:** SQLite with aggregation (daily summaries only)

---

## Final Recommendations

### For Your Use Case

**If using at home:**
```
Keep: 7-day ETS history (~120 KB)
Why:  Perfect for daily patterns, minimal resource use
```

**If using commercially:**
```
Extend to: 30-day ETS history (~520 KB)
Why:  Monthly reporting, still safe on Pi Zero
```

**If doing research:**
```
Extend to: 90-day ETS history (~1.5 MB)
Backup:  Export to CSV weekly
Why:   Long-term patterns, backup prevents data loss
```

**If you need >1 year:**
```
Switch to: SQLite with daily aggregation
Storage:   Keep last 90 days in ETS for speed
Archive:   Older data to SQLite on SD card
Memory:    ~1.5 MB ETS + ~5 MB SQLite
Caution:   Monitor SD card wear
```

---

## Quick Reference Card

```elixir
# Current: 24 hours
GasSensor.History.memory_usage() / 1024  # ~17 KB

# Extend to: 7 days
# Change @retention_seconds to 604_800
# Memory: ~120 KB

# Extend to: 30 days
# Change @retention_seconds to 2_592_000
# Memory: ~520 KB

# Extend to: 90 days
# Change @retention_seconds to 7_776_000
# Memory: ~1.5 MB

# Check capacity
Sampler.Monitoring.history_capacity()
Sampler.Monitoring.can_extend_history?(30)
```

---

## Bottom Line

**You can safely store:**
- ✅ **7 days** easily (~120 KB)
- ✅ **30 days** comfortably (~520 KB)
- ✅ **90 days** with monitoring (~1.5 MB)
- ✅ **1 year** if careful (~6 MB)

**The Pi Zero W has enough memory for 7-90 days of history** with plenty of safety margin!

**My recommendation for you:** Start with **30 days** - it gives you monthly patterns while using only ~520 KB (0.1% of available RAM).
