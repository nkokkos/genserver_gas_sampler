defmodule GasSensor.History do
  @moduledoc """

  ETS-based circular buffer for a maximum 7 days sensor history.

  The sensor readings include readings from the breakout board BME680 plus
  carbon monoxide ppm readings from the ads1115 adc module

  ## Architecture

  ```
  Sensor GenServer ──→ ETS Table (ordered_set)
                           │
                           ├── Key:    timestamp (DateTime)
                           ├── Values: reading tuple structure, see below
                           └── Size:   60,480 samples × 400 bytes ≈ 24,192,000 bytes. Zero W has ~300MB available for BEAM
                           │
                           ↓
                    Phoenix LiveView
                    (reads via API)
  ```

  ## Memory Efficiency

  We sample every 15 seconds for the maximum time of 7 days = 604800 seconds / 15 seconds = 40,320 samples 
  in 7 days

  - 60,480 samples × 400 bytes ≈ 24,192,000 bytes
  - Pi Zero W has ~300MB available for BEAM

  ## Why did we use ETS?

  1. **O(1) lookups** - Fast access by time range
  2. **Concurrent reads** - Multiple web clients without blocking
  3. **No disk I/O** - Preserves SD card, faster than SQLite
  4. **Built-in** - No extra dependencies
  5. **Automatic cleanup** - Old entries deleted automatically

  ## Usage

      # Note!! Adding samples to the history is done through
      # GasSensor.ReadingAgent by calling the following function: 
      # GasSensor.History.record_to_ets(final_timestamp, reading_with_timestamp)
      # inside the GasSensor.ReadingAgent.update function
      # Read the GasSensor.ReadingAgent.update function for more.

      # Get last 24 hours
      samples = GasSensor.History.get_last_24h()
   
      # Get last 7 days 
      samples = GasSensor.History.get_last_7_days()
   
      # Get downsampled data for graph (400 points max)
      graph_data = GasSensor.History.get_for_graph(400)

      # Get specific time range
      range = GasSensor.History.get_range(
        DateTime.add(DateTime.utc_now(), -1, :hour),
        DateTime.utc_now()
      )
  """

  use GenServer
  require Logger

  # table name used in ETS storage scheme
  @table_name :sensor_history

  # 7 days retention
  @retention_seconds		604800 # 7 days in seconds

  # 24 hours retention
  @retention_seconds_24h	86400  # 24 hours in seconds 
  
  # Cleanup every               60 seconds, 60_000 here refers to milliseconds
  @cleanup_interval 60_000
  
  # Maximum points to render for 24 hours
  @max_samples_for_graph 400

  # Maximum points to render for 7 days / 168 hours
  @max_samples_for_7_days_graph 300


  # ── Public API ──────────────────────────────────────────

  @doc """
  Records a reading directly into the ETS table.
  Called by GasSensor.ReadingAgent.
  """
  def record_to_ets(timestamp, reading) do
    unix_ts = DateTime.to_unix(timestamp, :millisecond)
    :ets.insert(@table_name, {unix_ts, reading})
  end

  @doc """
  Starts the History GenServer and creates the ETS table.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @doc """
  Gets all samples from the last 24 hours.
  Returns list of %{timestamp: DateTime, reading_tuple, status: atom}
  """
  def get_last_24h do
    # Use reliable timestamp (handles Pi Zero W without RTC)
    {now, _reliable?} = GasSensorWeb.Simulator.Timestamp.now()
    cutoff = DateTime.add(now, -@retention_seconds_24h)
    get_since(cutoff)
  end

  @doc """
  Gets all samples from the last 7 days
  """
  def get_last_7_days do 
   # Use reliable timestamp (handles Pi Zero W without RTC)
   {now, _reliable?} = GasSensorWeb.Simulator.Timestamp.now()
   cutoff = DateTime.add(now, -@retention_seconds)
   get_since(cutoff)
  end

  @doc """
  Gets samples since a specific time.

  ## Examples

      # Last hour
      one_hour_ago = DateTime.add(DateTime.utc_now(), -3600)
      samples = Core.History.get_since(one_hour_ago)
  """
  def get_since(%DateTime{} = datetime) do
    
    # Match spec for a 2-element tuple: {timestamp, reading_map}
    # $1 is the timestamp, $2 is the map containing your 7 metricsi
   
    cutoff_ms = DateTime.to_unix(datetime, :millisecond)

    match_spec = [
      {
        {:"$1", :"$2"},            # Pattern to match
        [{:>=, :"$1", cutoff_ms}], # Filter: timestamp >= datetime
        [{{:"$1", :"$2"}}]         # Result format: return the whole tuple
      }
    ]

    @table_name
    |> :ets.select(match_spec)
    |> Enum.map(fn {unix_ms, reading} ->
     # rebuild from the ETS key
     ts = DateTime.from_unix!(unix_ms, :millisecond)     
     
     reading 
     |> Map.put(:timestamp, ts)
     |> Map.put(:timestamp_iso, DateTime.to_iso8601(ts)) 
   end)
    # Since it's an :ordered_set, it's already sorted by timestamp.
    # This sort is just a safety measure for the graphing engine.
    |> Enum.sort_by(& &1.timestamp, DateTime)
   
    # Note this why we used DateTime.to_iso8601
    # :timestamp_iso
    # VegaLite cannot read Elixir DateTime structs. Use the :timestamp_iso field
  end


  @doc """
  Gets samples for graphing with automatic downsampling.

  Returns at most `max_points` samples by using min-max downsampling
  The best algorithm would be LTTB - Largest Triangle Three Buckets algorithm for visual accuracy.
  But it requires a strong cpu and the rasberry pi is not that strong
   

  ## Parameters

    * `max_points` - Maximum number of points to return (default: 400 for 24 hours)

  ## Examples

      # Get 24h history downsampled to 400 points for graph
      data = GasSensor.History.get_for_graph(400)

      # Get 7 days history downsampled for 300 points for graph
      data = GasSensor.History.get_for_7_days_graph()
     
  """
  def get_for_graph(max_points \\ @max_samples_for_graph) do
    samples = get_last_24h()
    downsample(samples, max_points)
  end

  def get_for_7_days_graph(max_points \\ @max_samples_for_7_days_graph) do
    samples = get_last_7_days()
    downsample(samples, max_points)
  end

  @doc """
  Gets the oldest sample in the history.
  """
  def get_oldest do
    # :ets.first returns the very first key in the :ordered_set (the newest time)
    case :ets.first(@table_name) do
      :"$end_of_table" ->
      nil

    timestamp ->
      # We look up the key and get back our 2-element tuple
      [{^timestamp, reading}] = :ets.lookup(@table_name, timestamp)

      # We merge the timestamp into the map so it's easy to use in Phoenix Live View
      Map.put(reading, :timestamp, timestamp)
    end
  end

  @doc """
  Gets the newest sample in the history.
  """
  def get_newest do
    # :ets.last returns the very last key in the :ordered_set (the latest time)
    case :ets.last(@table_name) do
      :"$end_of_table" ->
      nil

    timestamp ->
      # We look up the key and get back our 2-element tuple using the pin operator
      [{^timestamp, reading}] = :ets.lookup(@table_name, timestamp)
      
      # We merge the timestamp into the map so it's easy to use in Phoenix Live View
      Map.put(reading, :timestamp, timestamp)
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
    # See more there about ETS https://elixirschool.com/en/lessons/storage/ets
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
    # Calculate the "Expiration Date"
    {now, _reliable?} = GasSensorWeb.Simulator.Timestamp.now()
    cutoff = DateTime.add(now, -@retention_seconds, :second)

    # match_spec for 2-element tuple: {timestamp, reading_map}
    # $1 = timestamp, $2 = map
    match_spec = [
      {
        {:"$1", :"$2"},                  # Look for these 2-item tuples
        [{:<, :"$1", {:const, cutoff}}], # Condition: where timestamp is LESS THAN cutoff
        [true]                           # Return true = "Yes, delete this"
      }
    ]

    deleted = :ets.select_delete(@table_name, match_spec)
    
    if deleted > 0
      Logger.debug("Cleaned up #{deleted} old entries")
    end

    :ok
  end

  @doc """
  Reduces the number of data points (decimation) for visualization performance  while preserving critical environmental events.

  ## Why Downsampling?
  - **Hardware Constraints:** The Raspberry Pi Zero W has limited memory; sending 100k+ 
    rows to a browser for graphing can cause the Phoenix channel or the client's browser to crash.
  - **Visual Clarity:** A 650px chart cannot physically display more than ~650 vertical 
    lines of data. Excess points cause "aliasing" and visual noise.
  - **Data Preservation:** Unlike simple averaging (which hides gas spikes), this 
    algorithm uses a **Min-Max Bucket** strategy to ensure safety-critical events 
    (like CO peaks) remain visible.

  ## The Algorithm: Representative Peak Selection
  1. **Bucket Calculation:** Divides the dataset into `n` equal temporal buckets.
  2. **Feature Extraction:** For every bucket, it identifies:
      - The **First** sample (to maintain chronological continuity).
      - The **Peak CO** sample (to capture the "worst-case" air quality event).

  ## Parameters
    - `samples`: A list of `%GasSensor.Sample{}` structs containing 7 environmental metrics.
    - `max_points`: The target number of points to display (usually matched to UI width).

  ## Returns
    - A list of samples where `length(samples) <= max_points * 2`.
  """
  defp downsample(samples, max_points) when length(samples) <= max_points, do: samples

  defp downsample(samples, max_points) do
    
    # Calculate the 'temporal width' of a single pixel-cluster

    bucket_size = max(1, div(length(samples), max_points))

    # chunk_every produces:
    # [
    #  [r1, r2, r3, r4, r5],   # bucket 1
    #  [r6, r7, r8, r9, r10],  # bucket 2
    #  [r11, r12, r13, r14, r15] # bucket 3
    # ]

   # Example here to understand better: --->
   # flat_map receives each bucket ONE AT A TIME:

   # iteration 1 → bucket = [r1, r2, r3, r4, r5]
   # first   = r1
   # peak_co = Enum.max_by([r1,r2,r3,r4,r5], co_ppm)  # finds peak inside bucket 1 only

   # iteration 2 → bucket = [r6, r7, r8, r9, r10]
   # first   = r6
   # peak_co = Enum.max_by([r6,r7,r8,r9,r10], co_ppm) # finds peak inside bucket 2 only

   # iteration 3 → bucket = [r11, r12, r13, r14, r15]
   # first   = r11
   # peak_co = Enum.max_by([r11,r12,r13,r14,r15], co_ppm) # finds peak inside bucket 3 only
   # flat_map and map both iterate item by item. 
   # The only difference is flat_map flattens the result at the end. 

    samples
    |> Enum.chunk_every(bucket_size, bucket_size, :discard)
    |> Enum.map(fn bucket ->
      # We anchor the window with the first point and the most dangerous point (Peak CO)
      first = List.first(bucket)
      peak_co = Enum.max_by(bucket, &Map.get(&1, :co_ppm, 0.0))
   
      # Avoid duplicating when first == peak
      if first == peak_co do  
        [first] 
      else 
        [first, peak_co]
      end
     end)
    |> Enum.uniq_by(& &1.timestamp) 
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.take(max_points)
  end


end
