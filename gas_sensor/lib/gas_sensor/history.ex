defmodule GasSensor.History do
  @moduledoc """

  ETS-based circular buffer for a maximum 7 days sensor history.

  This module stores all sensor readings in an in-memory ETS table,
  providing O(1) access to historical data for graphing and analysis.
  Automatic cleanup removes entries older than 168 hours.

  The sensor readings include readings from the breakout board BME680 plus
  carbon monoxide ppm readings from the ads1115 adc module

  Each reading is a tuple defined as follows in the following example
  co_ppm: 50, 		# this is calculated from adc samples
  temperature_c: 34, 	# bme680 breakout board
  humidity_rh: 80,      # bme680 breakout board
  dew_point_c: 2.629,   # bme680 breakout board
  gas_resistance_ohms: 5279.474, # bme680 breakout board
  pressure_pa: 100818.86273677988, # bme680 breaout board
  cpu_temperature: 35,  # read from the rpi0 cpu 
  status: :ok or :error # status attached to the reading

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

  We sample every 10 seconds for the maximum time of 7 days = 604800 seconds / 10 seconds = 60,480 samples 
  in 7 days

  - 60,480 samples × 400 bytes ≈ 24,192,000 bytes
  - Pi Zero W has ~300MB available for BEAM

  ## Why did we use ETS?

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

      # Add a reading (called by Core.Sensor GenServer)
      reading = tuple that contains the timestamp and all the readings
      Core.History.add_sample(reading, :ok)

      # Get last 24 hours
      samples = Core.History.get_last_24h()
   
      # Get last 7 days 
      samples = Core.History.get_last_7_days()
   
      # Get downsampled data for graph (400 points max)
      graph_data = Core.History.get_for_graph(400)

      # Get specific time range
      range = Core.History.get_range(
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

  # 7 days in hours:
  @max_retention_hours		168    # 7 days in hours
  
  # Cleanup every 60 seconds, 60_000 here refers to milliseconds
  @cleanup_interval 60_000
  
  # Maximum points to render for 24 hours
  @max_samples_for_graph 400

  # Maximum points to render for 7 days / 168 hours
  @max_samples_for_7_days_graph 300


  # ── Public API ──────────────────────────────────────────

  @doc """
  Starts the History GenServer and creates the ETS table.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Adds a new sample to the history.

  Called by Core.Sensor GenServer after each median-filtered reading.
  Automatically includes timestamp.

  ## Examples
    ok_reading = %{
      co_ppm: 50,
      temperature_c: 34,
      humidity_rh: 80,
      dew_point_c: 2.629,
      gas_resistance_ohms: 5279.474,
      pressure_pa: 100818.86273677988,
      cpu_temperature: 35,
      status: :ok # Add a status flag for easy filtering
    }

    null_reading = %{
      co_ppm: nil,
      temperature_c: nil,
      humidity_rh: nil,
      dew_point_c: nil,
      gas_resistance_ohms: nil,
      pressure_pa: nil,
      cpu_temperature: nil,
      status: :error # Add a status flag for easy filtering
    }
 
      Core.History.add_sample(ok_reading,   :ok)
      Core.History.add_sample(null_reading, :error)
  """
  def add_sample(%{
    co_ppm: _,
    temperature_c: _,
    humidity_rh: _,
    dew_point_c: _,
    gas_resistance_ohms: _,
    pressure_pa: _,
    cpu_temperature: _
  } = reading, status) when is_atom(status) do 
    {timestamp, reliable?} = GasSensor.Timestamp.now_with_reliability()
    final_timestamp =
      if reliable?, do: timestamp, else: GasSensor.Timestamp.provisional_timestamp()
    :ets.insert(@table_name, {final_timestamp, reading})
    :ok
  end

  @doc """
  Gets all samples from the last 24 hours.
  Returns list of %{timestamp: DateTime, reading_tuple, status: atom}
  """
  def get_last_24h do
    # Use reliable timestamp (handles Pi Zero W without RTC)
    cutoff = DateTime.add(GasSensor.Timestamp.now(), -@retention_seconds_24h)
    get_since(cutoff)
  end

  @doc """
  Gets all samples from the last 7 days
  """
  def get_last_7_days do 
   # Use reliable timestamp (handles Pi Zero W without RTC)
   cutoff = DateTime.add(GasSensor.Timestamp.now(), -@retention_seconds)
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
    # $1 is the timestamp, $2 is the map containing your 7 metrics
    match_spec = [
      {
        {:"$1", :"$2"},                      # Pattern to match
        [{:>=, :"$1", {:const, datetime}}],  # Filter: timestamp >= datetime
        [{{:"$1", :"$2"}}]                   # Result format: return the whole tuple
      }
    ]

    @table_name
    |> :ets.select(match_spec)
    |> Enum.map(fn {ts, reading} ->
      # reading is the map %{co_ppm: _, temperature_c: _, ...}
      # We inject the timestamp into the map so the graphing tool has it in the same object
      Map.put(reading, :timestamp, ts)
    end)
    # Since it's an :ordered_set, it's already sorted by timestamp.
    # This sort is just a safety measure for the graphing engine.
    |> Enum.sort_by(& &1.timestamp, DateTime)
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
    cutoff = DateTime.add(GasSensor.Timestamp.now(), -@retention_seconds)

    # match_spec for 2-element tuple: {timestamp, reading_map}
    # $1 = timestamp, $2 = map
    match_spec = [
      {
        {:"$1", :"$2"},                  # Look for these 2-item tuples
        [{:<, :"$1", {:const, cutoff}}], # Condition: where timestamp is LESS THAN cutoff
        [true]                           # Return true = "Yes, delete this"
      }
    ]

    :ets.select_delete(@table_name, match_spec)

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
  3. **Reconstitution:** Merges, deduplicates, and re-sorts these samples to provide 
     a "High-Fidelity Envelope" of the 30-day run.

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

    samples
    |> Enum.chunk_every(bucket_size, bucket_size, :discard)
    |> Enum.map(fn bucket ->
      # We anchor the window with the first point and the most dangerous point (Peak CO)
      first = List.first(bucket)
      peak_co = Enum.max_by(bucket, & &1.co_ppm)

      [first, peak_co]
    end)
    |> List.flatten()
    |> Enum.uniq_by(& &1.timestamp) 
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.take(max_points)
  end


  @doc """
  Calculates the statistical median from a list of numeric sensor readings. 
  It not used here for the time being

  ## Why the Median?
  - **Noise Reduction:** Sensors can produce "spikes" due to transient electrical interference or power fluctuations. 
  - **Outlier Immunity:** Unlike the Mean (average), the Median is not skewed by 
    single erroneous readings. If 4 readings are ~5000 and 1 is 0 (error), the 
    median correctly stays at ~5000.

  ## Implementation Details
  - **Sorting:** The list is sorted in ascending order.
  - **Odd Count:** Returns the exact middle element.
  - **Even Count:** Returns the arithmetic mean of the two central elements.

  ## Parameters
    - `values`: A List of numbers (Integer or Float).

  ## Returns
    - A single numeric value (Integer or Float) representing the median.
  """
  defp calculate_median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    if rem(count, 2) == 1 do
      # Odd: Pick the middle
      Enum.at(sorted, div(count, 2))
    else
      # Even: Average the two middle points
      mid = div(count, 2)
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end

end
