# Code Starts here
defmodule SampleSensor do
  @moduledoc """
  GenServer for a Gas Sensor via ADS1115 ADC.
  Samples 7 times evenly spread over 5 seconds.
  Applies median filter and saves result to state.
  """

 # First read the datasheet from TI and undestand the configuration register
 # https://www.ti.com/lit/ds/symlink/ads1115.pdf?ts=1773639841733&ref_url=https%253A%252F%252Fwww.ti.com%252Fproduct%252FADS1115%253Futm_source%253Dgoogle%2526utm_medium%253Dcpc%2526utm_campaign%253Dasc-null-null-GPN_EN-cpc-pf-google-eu_en_cons%2526utm_content%253DADS1115%2526ds_k%253DADS1115+Datasheet%2526DCM%253Dyes%2526gclsrc%253Daw.ds%2526gad_source%253D1%2526gad_campaignid%253D8752110670%2526gclid%253DEAIaIQobChMIp5KkltujkwMVb8tEBx2uNifCEAAYASAAEgJO1_D_BwE#page=24&zoom=auto,-209,731

  # make this module a Genserver
  use GenServer
 
  require Logger
 
  # ADS1115 I2C address
  @ads1115_addr 0x48
 
  # Setup the ADS1115 registers
  @reg_conversion 0x00
  @reg_config     0x01
 
  # Define Config register bytes:

  # Byte 1: 10000101 = 0xC5
  #   OS   = 1   (start single conversion)
  #   MUX  = 000 (AIN0 - AIN1 differential)
  #   PGA  = 010 (±2.048V)
  #   MODE = 1   (single shot)

  # Byte 2: 00011011 = 0x83
  #   DR   = 000 (8 SPS)
  #   COMP = disabled
  @config_msb 0xC5
  @config_lsb 0x83

  # We use the default = 8 SPS (samples per second), therefore,
  # Conversion time = 1/8 = 125ms

  @conversion_ms  130     # 125ms conversion + 5ms margin
  @total_window   5_000   # 5 second window. We will be sampling 7 times over the period of 5 seconds.
  @num_samples    7       # odd number for clean median
  @sample_interval div(@total_window, @num_samples)  # 714ms
 
  # Sensor calibration
  # Update sensitivity using the label from the sensor!
  @sensitivity_na_per_ppm  1.827      # enter arbitrary value
  @r3_ohms                 1_200_000  # value of feedback resistor in Ohms
  @divider_factor          2.0        # undo ×0.5 voltage divide. Note that we used the voltage divider before sampling. We used a 2 MGOhn resistors to create a voltage divider.


  # ── Public API ──────────────────────────────────────────
 
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
 
  @doc "Returns current CO reading in ppm from state variable"
  def get_ppm do
    GenServer.call(__MODULE__, :get_ppm)
  end
 
  @doc "Returns full state for debugging"
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
 
  # ── GenServer Callbacks ──────────────────────────────────
 
  @impl true
  def init(_opts) do
    # Open I2C bus
    {:ok, ref} = Circuits.I2C.open("i2c-1")
 
    state = %{
      i2c:     ref,
      ppm:     0.0,
      samples: [],
      status:  :ok
    }
 
    # Start first sample immediately
    send(self(), :collect_sample)
 
    Logger.info("CoSensor started")
    {:ok, state}
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
    new_state =
      case read_ads1115(state.i2c) do
        {:ok, ppm} ->
          # Add new sample to window
          # Keep only last 7 samples (sliding!)
          window =
            [ppm | state.window]num_samples
            |> Enum.take(@num_samples)

          # Output median only when window is full
          filtered_ppm =
            if length(window) == @num_samples do
              median(window)
            else
              state.ppm
            end

          %{state | ppm: filtered_ppm, window: window}

        {:error, _reason} ->
          state
      end

    Process.send_after(self(), :collect_sample, @sample_interval)
    {:noreply, new_state}
  end


  # ── Private Functions ────────────────────────────────────
 
  defp read_ads1115(ref) do
    with :ok <- trigger_conversion(ref),
         :ok <- Process.sleep(@conversion_ms) |> then(fn _ -> :ok end),
         {:ok, raw} <- read_conversion(ref) do
      ppm = raw_to_ppm(raw)
      {:ok, ppm}
    end
  end
 
  defp trigger_conversion(ref) do
    Circuits.I2C.write(ref, @ads1115_addr, <<@reg_config, @config_msb, @config_lsb>>)
  end
 
  #defp read_conversion(ref) do
  #  with :ok <- Circuits.I2C.write(ref, @ads1115_addr, <<@reg_conversion>>),
  #       {:ok, <<msb, lsb>>} <- Circuits.I2C.read(ref, @ads1115_addr, 2) do
  #    # Convert to signed 16-bit integer
  #    raw = msb <<< 8 ||| lsb
  #    raw = if raw > 32767, do: raw - 65536, else: raw
  #    {:ok, raw}
  #  end
  #end

  # Reimplement read_conversion with atomic write_read!
  # Read this blog post where Frank talks about contention: https://elixirforum.com/t/do-we-need-to-write-linux-i2c-bus-atomic-operation-by-ourselves/64031/3
  # Just do atomic read just to be safe:
  defp read_conversion(ref) do
    raw_bytes = Circuits.I2C.write_read!(ref, @ads1115_addr, <<@reg_conversion>>, 2)
    <<msb, lsb>> = raw_bytes
    raw = msb <<< 8 ||| lsb
    raw = if raw > 32767, do: raw - 65536, else: raw
    {:ok, raw}
  rescue
    e -> {:error, e}
  end
 
  defp raw_to_ppm(raw) do
    # Step 1: raw ADC to millivolts (PGA ±2.048V = 0.0625mV per bit)
    # For more details, just read the ads1115 adc datasheet:
    mv = raw * 0.0625
 
    # Step 2: millivolts to volts
    voltage_diff = mv / 1000.0
 
    # Step 3: undo ×0.5 voltage divider (R6/R7 and R8/R9)
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
    Enum.at(sorted, div(length(sorted), 2))
  end


end
