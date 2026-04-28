defmodule GasSensor.ReadingAgent do
  @moduledoc """

  Agent that stores the latest sensor readings for non-blocking access.

  This Agent acts as a read-optimized cache between the I2C-reading GenServer
  and the Phoenix web interface. It prevents I2C bus contention by ensuring
  only the GenServer performs I2C operations.

  Stores the latest sensor reading for non-blocking access by the web interface.

  Only the Sensor GenServer writes here. Phoenix LiveView reads from here.

  Prevents I2C bus contention — web requests never wait for hardware.

  ## Usage

      # Get current reading (non-blocking, O(1))
      reading = GasSensor.ReadingAgent.get_reading()
      
      # Get just the PPM value
      ppm = GasSensor.ReadingAgent.get_ppm()
      
      # Update from GenServer (called internally)
      GasSensor.ReadingAgent.update(reading_map)

  ## Design Rationale

  Using an Agent here (rather than direct GenServer calls from Phoenix) provides:

  1. **No I2C Contention**: Only the Sensor GenServer touches the I2C bus
  2. **Non-blocking Reads**: Web requests never wait for I2C operations
  3. **Fault Isolation**: Web interface can still read last known value even if sensor errors
  4. **Better Concurrency**: Multiple web requests can read simultaneously without GenServer bottlenecks
  """

  # time_reliable is true when NTP has synced (RTC-less systems)

  @default_reading %{
    co_ppm:               0.0,
    temperature_c:        0.0,
    humidity_rh:          0.0,
    dew_point_c:          0.0,
    gas_resistance_ohms:  0.0,
    pressure_pa:	  0.0, 
    cpu_temperature:      0.0,
    timestamp:            nil,  
    time_reliable:	  false,
    status:               :not_started,
  }

  @agent_name __MODULE__

  @doc """
  Starts the Agent with default empty reading state.

  This should be started before the Sensor GenServer in the supervision tree.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> @default_reading end, name: @agent_name)
  end

  @doc """
  Gets the current reading from the Agent.

  Returns the full reading map including :ppm, :window, :status, :sample_count, :timestamp

  ## Examples

      iex> GasSensor.ReadingAgent.get_reading()
      %{co_ppm: 45.32, temperature: 30.0, .... window: [45.1, 45.5, 45.2,.....], status: :ok, timestamp: ~U[2024-01-15 10:30:00Z]}
  """
  def get_reading do
    Agent.get(@agent_name, & &1)
  end

  @doc """
  Gets just the current PPM value.

  Convenience function for when you only need the PPM reading.

  ## Examples

      iex> GasSensor.ReadingAgent.get_ppm()
      45.32
  """
  def get_ppm do
    Agent.get(@agent_name, & &1.co_ppm)
  end

  @doc """
  Gets just the current status.

  ## Examples

      iex> GasSensor.ReadingAgent.get_status()
      :ok
  """
  def get_status do
    Agent.get(@agent_name, & &1.status)
  end

  @doc """
  Checks if the stored timestamp is reliable (NTP has synced).

  On Pi Zero W without RTC, returns false until NTP synchronizes.
  Returns true once system time is accurate.

  ## Examples

      iex> GasSensor.ReadingAgent.time_reliable?()
      true
  """
  def time_reliable? do
    Agent.get(@agent_name, &Map.get(&1, :time_reliable, false))
  end

  @doc """
  Updates the Agent with a new reading.

  This should only be called by the Sensor GenServer after each I2C reading.
  Automatically adds a timestamp to the reading.

  ## Parameters

    * `reading` - Map containing :ppm, :window, :status, and all the othe readings
  """
  def update(reading) when is_map(reading) do
    # Check time reliability
    {timestamp, reliable?} = GasSensor.Timestamp.now_with_reliability()

    # If offline, use provisional timestamp (build date + monotonic offset)
    # This gives us unique, chronologically ordered timestamps even when
    # WiFi/NTP is unavailable
    final_timestamp =
      if reliable? do
        timestamp
      else
        GasSensor.Timestamp.provisional_timestamp()
      end

    reading_with_timestamp =
      reading
      |> Map.put(:timestamp, final_timestamp)
      |> Map.put(:time_reliable, reliable?)

    Agent.update(@agent_name, fn _ -> reading_with_timestamp end)
  end

  @doc """
  Child spec for use in supervision trees.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end
end
