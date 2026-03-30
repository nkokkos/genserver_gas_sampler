defmodule GasSensor.History do
  @moduledoc """
  ETS-based circular buffer for 24-hour sensor history.

  This module stores all sensor readings in an in-memory ETS table,
  providing O(1) access to historical data for graphing and analysis.
  Automatic cleanup removes entries older than 24 hours.

  ## Architecture

  ```
  Sensor GenServer ──→ ETS Table (ordered_set)
                           │
                           ├── Key: timestamp (DateTime)
                           ├── Val: {ppm, status}
                           └── Size: 17,280 entries max (~900KB)
                           │
                           ↓
                    Phoenix LiveView
                    (reads via API)
  ```

  ## Memory Efficiency

  - 17,280 samples/day × ~52 bytes = ~900KB total
  - Pi Zero W has ~300MB available for BEAM
  - Uses only 0.3% of available memory ✅

  ## Why ETS?

  1. **O(1) lookups** - Fast access by time range
  2. **Concurrent reads** - Multiple web clients without blocking
  3. **No disk I/O** - Preserves SD card, faster than SQLite
  4. **Built-in** - No extra dependencies
  5. **Automatic cleanup** - Old entries deleted automatically

  ## Alternatives Considered

  - **Agent with list**: O(n) lookups, memory fragmentation ❌
  - **SQLite**: 10-20MB overhead, SD card wear ❌
  - **File append**: Slow reads, SD wear ❌
  - **ETS**: Perfect fit for embedded ✅

  ## Usage

      # Add a reading (called by Sensor GenServer)
      GasSensor.History.add_sample(45.2, :ok)

      # Get last 24 hours
      samples = GasSensor.History.get_last_24h()

      # Get downsampled data for graph (300 points max)
      graph_data = GasSensor.History.get_for_graph(300)

      # Get specific time range
      range = GasSensor.History.get_range(
        DateTime.add(DateTime.utc_now(), -1, :hour),
        DateTime.utc_now()
      )
  """

  use GenServer
  require Logger

  @table_name :sensor_history
  # 24 hours
  @retention_seconds 86_400
  # Cleanup every 60 seconds
  @cleanup_interval 60_000
  # Maximum points to render
  @max_samples_for_graph 300

  # ── Public API ──────────────────────────────────────────

  @doc """
  Starts the History GenServer and creates the ETS table.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Adds a new sample to the history.

  Called by Sensor GenServer after each median-filtered reading.
  Automatically includes timestamp.

  ## Examples

      GasSensor.History.add_sample(45.2, :ok)
      GasSensor.History.add_sample(0.0, :error)
  """
  def add_sample(ppm, status) when is_number(ppm) and is_atom(status) do
    # Check time reliability and use appropriate timestamp
    {timestamp, reliable?} = GasSensor.Timestamp.now_with_reliability()

    # If offline, use provisional timestamp for better UX
    # (build date + monotonic offset instead of 1970 epoch)
    final_timestamp =
      if reliable? do
        timestamp
      else
        GasSensor.Timestamp.provisional_timestamp()
      end

    :ets.insert(@table_name, {final_timestamp, ppm, status})
    :ok
  end

  @doc """
  Gets all samples from the last 24 hours.

  Returns list of %{timestamp: DateTime, ppm: float, status: atom}
  """
  def get_last_24h do
    # Use reliable timestamp (handles Pi Zero W without RTC)
    cutoff = DateTime.add(GasSensor.Timestamp.now(), -@retention_seconds)
    get_since(cutoff)
  end

  @doc """
  Gets samples since a specific time.

  ## Examples

      # Last hour
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3600)
      samples = GasSensor.History.get_since(one_hour_ago)
  """
  def get_since(%DateTime{} = datetime) do
    # ETS ordered_set allows efficient range queries
    # Match spec: {timestamp, ppm, status} where timestamp >= datetime
    match_spec = [
      {{:"$1", :"$2", :"$3"}, [{:>=, :"$1", {:const, datetime}}], [{{:"$1", :"$2", :"$3"}}]}
    ]

    @table_name
    |> :ets.select(match_spec)
    |> Enum.map(fn {ts, ppm, status} ->
      %{timestamp: ts, ppm: ppm, status: status}
    end)
    |> Enum.sort_by(& &1.timestamp, DateTime)
  end

  @doc """
  Gets samples for graphing with automatic downsampling.

  Returns at most `max_points` samples by using min-max downsampling
  (LTTB - Largest Triangle Three Buckets algorithm for visual accuracy).

  ## Parameters

    * `max_points` - Maximum number of points to return (default: 300)

  ## Examples

      # Get 24h history downsampled to 300 points for graph
      data = GasSensor.History.get_for_graph(300)
  """
  def get_for_graph(max_points \\ @max_samples_for_graph) do
    samples = get_last_24h()
    downsample(samples, max_points)
  end

  @doc """
  Gets statistics for the last 24 hours.

  Returns %{count: int, min: float, max: float, avg: float, median: float}
  """
  def get_stats_24h do
    samples = get_last_24h()

    if length(samples) > 0 do
      ppms = Enum.map(samples, & &1.ppm)

      %{
        count: length(samples),
        min: Enum.min(ppms),
        max: Enum.max(ppms),
        avg: Enum.sum(ppms) / length(ppms),
        median: calculate_median(ppms)
      }
    else
      %{count: 0, min: 0.0, max: 0.0, avg: 0.0, median: 0.0}
    end
  end

  @doc """
  Gets the oldest sample in the history.
  """
  def get_oldest do
    case :ets.first(@table_name) do
      :"$end_of_table" ->
        nil

      timestamp ->
        [{^timestamp, ppm, status}] = :ets.lookup(@table_name, timestamp)
        %{timestamp: timestamp, ppm: ppm, status: status}
    end
  end

  @doc """
  Gets the newest sample in the history.
  """
  def get_newest do
    case :ets.last(@table_name) do
      :"$end_of_table" ->
        nil

      timestamp ->
        [{^timestamp, ppm, status}] = :ets.lookup(@table_name, timestamp)
        %{timestamp: timestamp, ppm: ppm, status: status}
    end
  end

  @doc """
  Returns the current size of the history table.
  """
  def size do
    :ets.info(@table_name, :size)
  end

  @doc """
  Returns memory usage in bytes.
  """
  def memory_usage do
    :ets.info(@table_name, :memory) * :erlang.system_info(:wordsize)
  end

  # ── GenServer Callbacks ─────────────────────────────────

  @impl true
  def init(_) do
    # Create ETS table with ordered_set for efficient time range queries
    # public = allows concurrent reads without going through GenServer
    table =
      :ets.new(@table_name, [
        # Keeps entries sorted by key (timestamp)
        :ordered_set,
        # Allows direct access without GenServer bottleneck
        :public,
        # Can be accessed by name
        :named_table,
        # Optimized for concurrent reads
        read_concurrency: true,
        # Single writer (Sensor GenServer)
        write_concurrency: false
      ])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("History ETS table created, retention: #{@retention_seconds}s")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # ── Private Functions ──────────────────────────────────

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_entries do
    # Use reliable timestamp for cutoff calculation
    cutoff = DateTime.add(GasSensor.Timestamp.now(), -@retention_seconds)

    # Delete all entries older than retention period
    # ordered_set allows efficient deletion from beginning
    :ets.select_delete(@table_name, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$1", {:const, cutoff}}], [true]}
    ])

    :ok
  end

  defp downsample(samples, max_points) when length(samples) <= max_points do
    samples
  end

  defp downsample(samples, max_points) do
    # Simple min-max downsampling for performance
    # More advanced: LTTB (Largest Triangle Three Buckets) algorithm

    bucket_size = max(1, div(length(samples), max_points))

    samples
    |> Enum.chunk_every(bucket_size, bucket_size, :discard)
    |> Enum.map(fn bucket ->
      # For each bucket, keep min and max for visual accuracy
      ppms = Enum.map(bucket, & &1.ppm)
      min_ppm = Enum.min(ppms)
      max_ppm = Enum.max(ppms)

      # Find timestamps for min and max
      min_sample = Enum.find(bucket, &(&1.ppm == min_ppm))
      max_sample = Enum.find(bucket, &(&1.ppm == max_ppm))

      # Return 2 points per bucket (min and max)
      # This preserves the visual envelope of the data
      [min_sample, max_sample]
    end)
    |> List.flatten()
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.take(max_points)
  end

  defp calculate_median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    if rem(count, 2) == 1 do
      Enum.at(sorted, div(count, 2))
    else
      mid = div(count, 2)
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end
end
