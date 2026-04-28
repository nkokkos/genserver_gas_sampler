defmodule GasSensor.Timestamp do
  @moduledoc """
  Reliable UTC timestamp generation for RTC-less embedded systems.

  Handles two critical scenarios on Raspberry Pi Zero W:
  1. **Normal boot with WiFi:** NTP syncs within 60 seconds → accurate timestamps
  2. **Offline/no WiFi:** Time stays at 1970 or build date → provisional timestamps

  ## Offline Mode Handling

  When WiFi is unavailable or NTP cannot sync:
  - Timestamps show 1970 or firmware build date
  - All samples marked as `time_reliable: false`
  - System enters "offline mode" - warnings throttled to avoid log spam
  - Data is still stored (better than losing it)
  - Relative ordering maintained via monotonic counters

  ## WiFi Recovery

  When WiFi reconnects and NTP syncs:
  - System detects time jump (1970 → current date)
  - New samples get accurate timestamps
  - Old samples remain with provisional timestamps
  - History cleanup may behave unexpectedly (24h window calculated from new time)

  ## Usage

      # Get timestamp with reliability check
      {timestamp, reliable?} = GasSensor.Timestamp.now_with_reliability()
      
      # Check NTP sync status
      synced? = GasSensor.Timestamp.ntp_synced?()
      
      # Check if we're in offline mode
      offline? = GasSensor.Timestamp.offline_mode?()
      
      # Get provisional timestamp (for offline data)
      timestamp = GasSensor.Timestamp.provisional_timestamp()
  """

  require Logger

  # Safe threshold - anything before this year is definitely wrong
  @minimum_reliable_year 2025

  # Throttle warning logs (don't spam every sample)
  # 30 seconds between warnings
  @warning_throttle_ms 30_000

  # Process dictionary keys for tracking state
  @last_warning_key :timestamp_last_warning
  @offline_mode_key :timestamp_offline_mode
  @boot_time_key :timestamp_boot_time

  @doc """
  Initializes the timestamp module state.

  Should be called once at application startup.
  """
  def init do
    # Record boot time for monotonic reference
    Process.put(@boot_time_key, System.monotonic_time(:millisecond))
    Process.put(@last_warning_key, 0)
    Process.put(@offline_mode_key, false)
    :ok
  end

  @doc """
  Returns current UTC timestamp with reliability check.

  ## Offline Mode Detection

  If the system time is obviously wrong (year < 2020), this indicates:
  - No WiFi connection
  - NTP servers unreachable
  - Network/firewall blocking NTP

  In this case:
  - Returns the current system time (even if wrong)
  - reliable? = false
  - Logs a warning (throttled to once per 30 seconds)
  - Marks system as "offline mode"

  ## Examples

      # With NTP sync (WiFi connected)
      GasSensor.Timestamp.now_with_reliability()
      # {~U[2024-03-30 14:25:18Z], true}

      # Without WiFi (1970 or build date)
      GasSensor.Timestamp.now_with_reliability()  
      # {~U[1970-01-01 00:05:42Z], false}
      # Logs: "WARNING: Operating in offline mode - timestamps provisional"
  """
  def now_with_reliability do
    timestamp = DateTime.utc_now()
    reliable = reliable_time?(timestamp)

    if reliable do
      # Time is good - if we were in offline mode, log recovery
      if offline_mode?() do
        log_time_recovery(timestamp)
        set_offline_mode(false)
      end

      {timestamp, true}
    else
      # Time is wrong - enter offline mode
      unless offline_mode?() do
        set_offline_mode(true)
      end

      log_offline_warning(timestamp)
      {timestamp, false}
    end
  end

  @doc """
  Returns current UTC timestamp (fast, no checks).

  Use when you just need a timestamp and don't care about reliability.
  """
  def now do
    DateTime.utc_now()
  end

  @doc """
  Returns a provisional timestamp for offline mode.

  When offline, this creates a timestamp that:
  - Uses the firmware build date as base
  - Adds monotonic time offset for uniqueness
  - Marks as provisional

  This gives us:
  1. Unique timestamps (no collisions)
  2. Relative ordering (chronological sequence)
  3. Indication that time is provisional

  ## Example Offline Sequence

      T+0s:    provisional_timestamp() →  ~U[2024-03-15 12:00:00Z] (build date + 0s)
      T+5s:    provisional_timestamp() →  ~U[2024-03-15 12:00:05Z] (build date + 5s)
      T+60s:   WiFi connects, NTP syncs
      T+61s:   now_with_reliability()  →  ~U[2024-03-30 14:26:00Z] (true time)
  """
  def provisional_timestamp do
    # Base: firmware build date (assumed 2024 for this firmware)
    # You should update this to match your actual build date
    # build_date = Application.get_env(:gas_sensor, :firmware_build_date, ~U[2024-03-30 00:00:00Z])
    
    # Grab the build date automatically:
    build_date = Nerves.Runtime.KV.get_active("nerves_fw_build_date") |> DateTime.from_iso8601()

    # Add monotonic offset for uniqueness
    elapsed_ms = System.monotonic_time(:millisecond) - boot_time_ms()
    elapsed_sec = div(elapsed_ms, 1000)

    DateTime.add(build_date, elapsed_sec)
  end

  @doc """
  Checks if system time appears to be synchronized.

  Returns true only if year >= 2020 (indicates NTP has likely synced).
  """
  def ntp_synced? do
    now()
    |> reliable_time?()
  end

  @doc """
  Checks if system is operating in offline mode.

  Offline mode means:
  - No WiFi connection OR
  - NTP cannot reach servers OR
  - Time has not synchronized yet
  """
  def offline_mode? do
    Process.get(@offline_mode_key, false)
  end

  @doc """
  Returns Unix timestamp (seconds since epoch).

  Note: This will be wrong if system time hasn't synced!
  Always check reliability first for critical timestamps.
  """
  def unix_now do
    System.os_time(:second)
  end

  @doc """
  Converts Unix timestamp to DateTime.
  """
  def from_unix(seconds) when is_integer(seconds) do
    DateTime.from_unix!(seconds)
  end

  @doc """
  Returns monotonic time in milliseconds.

  Safe for measuring durations - always increases regardless of system time changes.
  """
  def monotonic_ms do
    System.monotonic_time(:millisecond)
  end

  @doc """
  Returns monotonic time in seconds.
  """
  def monotonic_seconds do
    System.monotonic_time(:second)
  end

  @doc """
  Formats timestamp for human reading.
  """
  def format(%DateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S UTC")
  end

  @doc """
  Returns comprehensive time status information.

  Useful for debugging and monitoring dashboards.
  """
  def status do
    ts = now()
    reliable = reliable_time?(ts)
    offline = offline_mode?()

    %{
      current_time: ts,
      reliable: reliable,
      offline_mode: offline,
      year: ts.year,
      unix_timestamp: DateTime.to_unix(ts),
      monotonic_ms: monotonic_ms(),
      uptime_ms: monotonic_ms() - boot_time_ms(),
      provisional_time: if(offline, do: provisional_timestamp(), else: nil),
      warning:
        cond do
          offline and not reliable ->
            "Offline mode: WiFi/NTP unavailable. Timestamps provisional."

          not reliable ->
            "Time not synced (year: #{ts.year}). NTP may be initializing."

          offline ->
            "Time recovered from offline mode"

          true ->
            nil
        end
    }
  end

  # Private functions

  defp reliable_time?(%DateTime{year: year}) when year < @minimum_reliable_year do
    false
  end

  defp reliable_time?(%DateTime{year: year}) when year >= @minimum_reliable_year do
    true
  end

  defp set_offline_mode(bool) when is_boolean(bool) do
    Process.put(@offline_mode_key, bool)
  end

  defp boot_time_ms do
    Process.get(@boot_time_key, System.monotonic_time(:millisecond))
  end

  defp log_offline_warning(timestamp) do
    # Throttle warnings to avoid log spam
    last_warning = Process.get(@last_warning_key, 0)
    now_ms = System.monotonic_time(:millisecond)

    if now_ms - last_warning > @warning_throttle_ms do
      Process.put(@last_warning_key, now_ms)

      Logger.warning("""
      Operating in OFFLINE MODE - Timestamps are provisional
      Current system time: #{format(timestamp)}
      Reason: Year #{timestamp.year} < #{@minimum_reliable_year} 
      (indicates no NTP sync - likely WiFi disconnected)
      Data will still be stored but timestamps may be inaccurate.
      Connect to WiFi for accurate timestamps.
      """)
    end
  end

  defp log_time_recovery(timestamp) do
    Logger.info("""
    Time synchronization recovered!
    System time now accurate: #{format(timestamp)}
    New samples will have reliable timestamps.
    Old samples (from offline mode) remain provisional.
    """)
  end
end
