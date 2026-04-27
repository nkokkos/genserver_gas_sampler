defmodule Core.Sensor do
  @moduledoc """
  GenServer for the TGS5042 Gas Sensor via ADS1115 ADC.

  Samples 11 times evenly spread every 10 seconds.
  Applies median filter and saves result to state.

  ## Architecture Note

  This GenServer is the ONLY process that accesses the I2C bus.
  After each reading, it updates the GasSensor.ReadingAgent,
  which provides non-blocking access for the Phoenix web interface.

  This design prevents I2C bus contention and ensures:
  - Single writer to I2C (no race conditions)
  - Fast reads for web interface (no I2C wait times)
  - Better fault isolation

  ## Usage

      # Start the sensor (automatically started with the application)
      {:ok, pid} = GasSensor.Sensor.start_link()
      
      # Get current PPM reading (prefer Agent for non-blocking access)
      ppm = GasSensor.ReadingAgent.get_ppm()
      
      # Get full state from Agent
      reading = GasSensor.ReadingAgent.get_reading()
  """

  use GenServer
  require Logger
  import Bitwise
  alias GasSensor.Timestamp

  # ADS1115 I2C address
  @ads1115_addr 0x48

  # BME680 Breakoutboard address
  @bme680_addr 0x76

  @conversion_ms 140 	# time to wait for the conversion register to get ready
  @total_window  10_000  # how often should we sample
  @num_samples   11
  @sample_interval div(@total_window, @num_samples)

  # TGS_5042 Sensor calibration: 
  @sensitivity_na_per_ppm 1.525 	# this is the number printed on the module we got.
  @r3_ohms 		  1_200_000     # feed back resistor connected to the mcp6042 Op amp
  @divider_factor 	  ( 9.95 / (9.95 + 9.95) ) 

  # ── Public API ──────────────────────────────────────────

  @doc """
  Starts the GasSensor GenServer.

  ## Options

    * `:name` - Registers the process with the given name (default: `GasSensor.Sensor`)
    * `:i2c_bus` - I2C bus name (default: "i2c-1")
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns current CO reading in ppm from state.

  NOTE: For non-blocking access from web interface, use:
    GasSensor.ReadingAgent.get_ppm()
  """
  def get_ppm(server \\ __MODULE__) do
    GenServer.call(server, :get_ppm)
  end

  @doc """
  Returns full state for debugging.

  NOTE: For non-blocking access from web interface, use:
    GasSensor.ReadingAgent.get_reading()
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  # ── GenServer Callbacks ──────────────────────────────────

  @impl true
  def init(opts) do
    i2c_bus = Keyword.get(opts, :i2c_bus, "i2c-1")

    case Circuits.I2C.open(i2c_bus) do
      {:ok, ref} ->
        state = %{
          i2c: ref,
          ppm: 0.0,
          window: [],
          status: :ok,
          sample_count: 0
        }

        # Start first sample immediately
        send(self(), :collect_sample)

        Logger.info("GasSensor started on #{i2c_bus}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to open I2C bus #{i2c_bus}: #{inspect(reason)}")
        # Update Agent with error status even if we can't start
        GasSensor.ReadingAgent.update(%{
          ppm: 0.0,
          window: [],
          status: :error,
          sample_count: 0
        })

        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_ppm, _from, state) do
    {:reply, state.ppm, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:collect_sample, state) do

     # iex> {:ok, bmp} = BMP280.start_link(bus_name: "i2c-1", bus_address: 0x77)
     # 3{:ok, #PID<0.29929.0>}
     # iex> BMP280.measure(bmp)
     # {:ok,
     # %BMP280.Measurement{
     #   altitude_m: 138.96206905098805,
     #   dew_point_c: 2.629181073094435,
     #   gas_resistance_ohms: 5279.474749704044,
     #   humidity_rh: 34.39681642351278,
     #   pressure_pa: 100818.86273677988,
     #   temperature_c: 18.645856498100876,
     #   timestamp_ms: 885906
     # }}

     # BMP280.force_altitude(bmp, 100)
     # :ok

    new_state =
      case read_ads1115(state.i2c) do
        {:ok, ppm} ->
          # Add new sample to window (sliding window of last @num_samples)
          window =
            [ppm | state.window]
            |> Enum.take(@num_samples)

          # Calculate median only when window is full
          filtered_ppm =
            if length(window) == @num_samples do
              median(window)
            else
              state.ppm
            end

          updated_state = %{
            state
            | ppm: filtered_ppm,
              window: window,
              sample_count: state.sample_count + 1,
              status: :ok
          }

          # Update the Agent for non-blocking reads
          GasSensor.ReadingAgent.update(updated_state)

          # Add to 24-hour history (only when window is full = valid median)
          if length(window) == @num_samples do
            GasSensor.History.add_sample(filtered_ppm, :ok)
          end

          updated_state

        {:error, reason} ->
          Logger.warning("Failed to read sensor: #{inspect(reason)}")
          error_state = %{state | status: :error}

          # Update Agent with error status
          GasSensor.ReadingAgent.update(error_state)

          # Add error to history with 0.0 PPM
          GasSensor.History.add_sample(0.0, :error)

          error_state
      end

    # Schedule next sample
    Process.send_after(self(), :collect_sample, @sample_interval)
    {:noreply, new_state}
  end

  # ── Private Functions ────────────────────────────────────

  defp read_ads1115(ref) do
    with :ok <- trigger_conversion(ref),
         :ok <- wait_for_conversion(),
         {:ok, raw} <- read_conversion(ref) do
      ppm = raw_to_ppm(raw)
      {:ok, ppm}
    else
      error -> error
    end
  end

  defp trigger_conversion(ref) do
    Circuits.I2C.write(ref, @ads1115_addr, <<@reg_config, @config_msb, @config_lsb>>)
  end

  defp wait_for_conversion do
    Process.sleep(@conversion_ms)
    :ok
  end

  defp read_conversion(ref) do
    case Circuits.I2C.write_read(ref, @ads1115_addr, <<@reg_conversion>>, 2) do
      {:ok, <<msb, lsb>>} ->
        raw = msb <<< 8 ||| lsb
        raw = if raw > 32767, do: raw - 65536, else: raw
        {:ok, raw}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp raw_to_ppm(raw) do
    # Step 1: raw ADC to millivolts (PGA ±2.048V = 0.0625mV per bit)
    mv = raw * 0.0625

    # Step 2: millivolts to volts
    voltage_diff = mv / 1000.0

    # Step 3: undo voltage divider
    actual_diff = voltage_diff * @divider_factor

    # Step 4: convert to ppm
    # ppm = actual_diff / (sensitivity_A/ppm × R3)
    sensitivity_amps = @sensitivity_na_per_ppm * 1.0e-9
    ppm = actual_diff / (sensitivity_amps * @r3_ohms)

    # Clamp to valid range
    ppm
    |> max(0.0)
    |> min(10_000.0)
  end

  defp median(samples) do
    sorted = Enum.sort(samples)
    mid = div(length(sorted), 2)
    Enum.at(sorted, mid)
  end
end
