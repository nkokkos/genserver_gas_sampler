defmodule GasSensor.Sensor do
  @moduledoc """
  GenServer for the TGS5042 Gas Sensor via ADS1115 ADC.

  * Samples 11 times evenly spread every 10 seconds.
  * Applies median filter and saves result to state.

  ## Architecture Note

  This GenServer is the ONLY process that accesses the I2C bus.
  After each reading, it updates the GasSensor.ReadingAgent, which provides 
  non-blocking access for the Phoenix web interface.

  This design prevents I2C bus contention and ensures:
  - Single writer to I2C (no race conditions)
  - Fast reads for web interface (no I2C wait times)
  - Better fault isolation

  ## Usage
      
      # Get current PPM reading (prefer Agent for non-blocking access)
      ppm = GasSensor.ReadingAgent.get_ppm()
      
      # Get full state from Agent
      reading = GasSensor.ReadingAgent.get_reading()
  
  """

  use GenServer
  require Logger
  import Bitwise
  alias GasSensor.Timestamp

  # We use the breakout board ADS1115 adc for sampling the output of the sensor + reference voltage
  # https://www.skroutz.gr/s/54629997/Ads1115-I2c-16-Bit-Adc-4-Channel-Module.html

  # The configuration Register - Full 16 bits from the Datasheet:
  # https://www.ti.com/lit/ds/symlink/ads1115.pdf
  
  # Table 8-3 Config Register Field Descriptions
  # Bit:  15  14  13  12  11  10   9  8  7   6   5   4   3   2   1   0
  #      ├───┼───────────┼──────────┼───┼──────────┼───┼───┼───┼───────┤
  #      │OS │  MUX[2:0] │ PGA[2:0] │MOD│  DR[2:0] │CM │CP │CL │CQ[1:0]│
  #      └───┴───────────┴──────────┴───┴──────────┴───┴───┴───┴───────┘
  #       ←────────── MSB (byte 2) ──────────→←──────── LSB (byte 3) ───→

  # ── ADS1115 Config Register Constants ────────────────────
  # Reference: TI ADS1115 datasheet SBAS444E, Table 8-2
  #
  # MSB byte breakdown:
  #   Bit  15    OS  = 1       → start conversion immediately
  #   Bits 14-12 MUX           → which channel to read
  #   Bits 11-9  PGA = 001     → ±4.096V FSR, 0.000125V per count
  #   Bit  8     MODE = 1      → single-shot (converts once, then sleeps)
  #
  # LSB byte breakdown:
  #   Bits 7-5   DR = 000      → 8 SPS (125ms conversion, lowest noise)
  #   Bits 4-2                 → comparator settings, all 0 (unused)
  #   Bits 1-0   COMP_QUE = 11 → comparator disabled
  #
  # At 8 SPS: peak-to-peak noise = 125µV

  # ADS1115 Register Addresses:
  # The ADS1115 has 4 registers. We will use two:
  #   0x00 → Conversion register  — holds the ADC result
  #   0x01 → Config register      — controls all chip settings
  @reg_conversion = 0x00
  @reg_config     = 0x01

  # We will sample the reference voltage of 2Volts at A0 and at A1 the TGS5042 signal voltage
  @config_msb_a0    = 0xC3     # 1_100_001_1  → OS=1, MUX=AIN0/GND, PGA=±4.096V, single-shot
  @config_msb_a1    = 0xD3     # 1_101_001_1  → OS=1, MUX=AIN1/GND, PGA=±4.096V, single-shot
  @config_lsb       = 0x03     # 0_000_0_0_11 → DR=8SPS, comparator disabled

  @volts_per_count = 0.000125  # ±4.096V / 32768 counts = 125µV per LSB 

  # ASDS1115 configuration: 
  
  #ADS1115 I2C address
  @ads1115_addr 0x48
  
  @conversion_ms 140 	 # time to wait for the conversion register to get ready
  @total_window  10_000  # how often we should we sample the inputs
  @num_samples   11      # sample 11 times for the median filter
  @sample_interval       div(@total_window, @num_samples)

  # TGS_5042 Sensor calibration: 
  @sensitivity_na_per_ppm 1.525 	# this is the number printed on the module we got.
  @r3_ohms 		  1_200_000     # feed back resistor connected to the mcp6042 Op amp
  @divider_factor 	  ( 9.95 / (9.95 + 9.95) ) 
 
  # Temperature compensation table for TGS5042
  # This is based in the application note
  # "APPLICATION NOTES FOR TGS5xxx SERIES" - Revised 12/25
  
  # Appendix 2 - Temperature Compensation Coefficients for Residential Usage:
  @temp_cf_table %{
    -10 => 0.752, -9  => 0.761, -8  => 0.771, -7 => 0.780,
    -6  => 0.789, -5  => 0.799, -4  => 0.808, -3 => 0.817,
    -2  => 0.826, -1  => 0.835,  0  => 0.844, 1 => 0.852,
     2  => 0.861,  3  => 0.870,  4  => 0.878, 5 => 0.887,
     6  => 0.895,  7  => 0.903,  8  => 0.911, 9 => 0.919,
     10 => 0.927,  11 => 0.935,  12 => 0.943, 13 => 0.950,
     14 => 0.958,  15 => 0.965,  16 => 0.972, 17 => 0.980,
     18 => 0.987,  19 => 0.994,  20 => 1.000, 21 => 1.007,
     22 => 1.013,  23 => 1.020,  24 => 1.026, 25 => 1.032,
     26 => 1.038,  27 => 1.044,  28 => 1.050, 29 => 1.055,
     30 => 1.060,  31 => 1.066,  32 => 1.071, 33 => 1.076,
     34 => 1.080,  35 => 1.085,  36 => 1.089, 37 => 1.094,
     38 => 1.098,  39 => 1.101,  40 => 1.105, 41 => 1.109,
     42 => 1.112,  43 => 1.115,  44 => 1.118, 45 => 1.121,
     46 => 1.124,  47 => 1.126,  48 => 1.128, 49 => 1.130,
     50 => 1.132,  51 => 1.134,  52 => 1.135, 53 => 1.136,
     54 => 1.137,  55 => 1.138
  }
 
  #According to the datasheet at 6-3:
  #6-3 Temperature compensation
  # It is necessary to continuously write the thermistor output into the microprocessor. Inside the
  # microprocessor, temperature compensation is carried
  # out by using the compensation coefficient table shown in Appendix 2. 
  # CO sensitivity at 20˚C (α) is calculate by the following equation:
  # α = αt / CF
  # where:
  # CF = compensation coefficient at t˚ αt = CO sensitivity at t˚C
  # 6-4 Calculation of CO concentration
  # CO concentration (C) can be calculated by using
  # sensor output (Vout), sensor output in clean air (V0),
  # CO sensitivity at 20 ˚C (α), and feedback resistor (Rf)
  # in the following formula:
  # C = (V0 – Vout) / (α × Rf) [Equation 1]
  # When high accuracy is required, temperature
  # dependency of an op-amp should be considered
  
  # Please note, that since we use an non inverting analog setup in our 
  # circuits the correct formula for our case is:
  # C = (Vout - V0) / (α × Rf) where V0 = Offset voltage at 0 CO ppm 


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
   
    #reference to the bus
    i2c_bus = Keyword.get(opts, :i2c_bus, "i2c-1")
    
    #try to open the i2c bus
    case Circuits.I2C.open(i2c_bus) do
      {:ok, ref} ->
        state = %{
          
          # This is the default initial state when we try open the i2c bus for the first
          # time.

          # Internal to this genserver instance 
          i2c: ref,
          phase: :calibrating,	#:calibrating | :running
          calibration_samples: [],
          offset_mv: 0.0,

          # Telemetry - values that should be sent to the web interface/iot platform
          co_ppm: 0.0,
  	      temperature_c: 0.0,
  	      humidity_rh: 0.0,
  	      pressure_pa: 0.0,
  	      dew_point_c: 0.0,
  	      gas_resistance_ohms: 0.0,
          cpu_temperature: 0.0,       
	      adc_status: :no_reading,  # :ok | :error_i2c_bus | :no_reading
  	      temp_status: :no_reading, # :ok | :error_i2c_bus | :no_reading
          timestamp_ms: 0,

          # Diagnostics - these valus should be sent to webinterface / iot plaform too.
          a0_mv: 0.0, # A0 reference channel voltage — should stay ~2000mv

          a1_mv: 0.0, # A1 signal channel voltage — 
				      # raw voltage from the analog circuits where the TGS5042 is attached

          co_signal_mv: 0.0, # median of co_signal_samples — voltage in millivolts. 
				             # This voltage is then passed to mv_to_ppm() to produce ppm

          co_signal_samples: [] # 11 raw (A1×2)-A0 values in millivolts. Median of this list = co_signal_mv
        }

        # Start first sample immediately
        send(self(), :collect_sample)
        Logger.info("GasSensor started on #{i2c_bus}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to open I2C bus #{i2c_bus}: #{inspect(reason)}")
        # Update Agent with error status even if we can't start
        GasSensor.ReadingAgent.update(%{
          
          # Internal
          # Don't send internal metrics
          
          # Telemetry
          co_ppm: nil,
          temperature_c: nil,
          humidity_rh: nil,
          pressure_pa: nil,
          dew_point_c: nil,
          gas_resistance_ohms: nil,
          cpu_temperature: nil,
          adc_status: :error_i2c_bus,
          temp_status: :error_i2c_bus,
          timestamp_ms: nil,

          # Diagnostics
          a0_mv: nil, 
          a1_mv: nil, 
          co_signal_mv: nil, 
          co_signal_samples: nil 
        })
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_ppm, _from, state) do
    {:reply, state.co_ppm, state}
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
   
     # Read the data from the BME280.measure(:bme680)
     {:ok, bme680_data } =  BME280.measure(:bme680)

     # Read cpu temperature
     {:ok, cpu_temp } =  GasSensor.HardwareTemp.read_cpu_temp()

      # 
      # 11 samples for median filter
      samples = for _ <- 1..11, do: read_ads1115(state.i2c)

      # Separate good reads from failed reads
      {good, bad} = Enum.split_with(samples, fn
        {:ok, _} -> true
           _     -> false
       end)

       # Extract values and calculate median
       median_v =
         good
           |> Enum.map(fn {:ok, v} -> v end)
           |> Enum.sort()
           |> Enum.at(div(length(good), 2))

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

  defp publish_agent(state) do
   
  end

  defp read_ads1115(i2c_ref) do 
  
    with {:ok, raw_a0} <- read_channel(@config_msb_a0, i2c_ref),
         {:ok, raw_a1} <- read_channel(@config_msb_a1, i2c_ref) 
    do
      # 1. Convert raw counts to volts
      v_ref    = raw_a0 * @volts_per_count
      v_halved = raw_a1 * @volts_per_count

      # 2. Reconstruct the signal
      # Multiply by 2.0 to reverse the hardware voltage divider
      v_op_amp = v_halved * 2.0

      # 3. Calculate differential
      # This removes the ~2.0V bias of the reference singal to isolate the sensor signal
      differential = v_op_amp - v_ref
      {:ok, differential}
    else
      {:error, reason} -> {:error, reason}
    end
  
  end

  # ── Trigger and Read One Channel ──────────────────────────
  # Writes the config register to start a single-shot conversion
  # on the requested channel, waits for the OS bit to confirm
  # completion, then reads and returns the raw signed integer.
  #
  # config_msb selects the channel:
  # 0xC3 → AIN0/GND (my A0 reference voltage)
  # 0xD3 → AIN1/GND (my A1 signal voltage)
  defp read_channel(config_msb, i2c_ref)
  
    # Trigger conversion.
    # Write 3 bytes to the chip:
    #   byte 1: reg_config (0x01) → "This is the config register"
    #   byte 2: config_msb        → channel + PGA + single-shot + start
    #   byte 3: config_lsb        → 8 SPS + comparator disabled
    
    # If any step fails, it bubble the error to the caller
    with :ok <- Circuits.I2C.write(i2c_ref, @ads1115_addr, <<@reg_config, config_msb, @config_lsb>>),
         :ok <- wait_for_ready(i2c_ref),
         {:ok, raw_value} <- read_conversion(i2c_ref) do
    
      # If everything succeeded, we return the final result
      {:ok, raw_value}
    else
      # If ANY step above returned {:error, reason}, it lands here.
      # We simply pass that error back up the chain.
      {:error, reason} -> {:error, reason}
    
      # Optional: Catch-all for unexpected returns
      error -> {:error, error}
    end

  end
 

  # ── Read Conversion Result ────────────────────────────────
  # Reads the 16-bit signed result from the conversion register.
  #
  # Uses write_read (atomic):
  #   write: <<reg_conversion>> sets register pointer to 0x00
  #   read:  2 bytes returns the ADC result (MSB first)
  #   Single I2C transaction — bus held throughout.
  #   This is critical since BME680 and ADS1115 share the same bus.
  # Note these difference between atomic and not atomic:
  # Circuits.I2C.write(ref, address, <<0x00>>)   # transaction 1 — set pointer
  # Circuits.I2C.read(ref, address, 2)           # transaction 2 — read result
  # This code — ONE atomic I2C transaction
  # Circuits.I2C.write_read(ref, @ads1115_addr, <<@reg_conversion>>, 2)
  # write and read happen without releasing the bus between them
  defp read_conversion(i2c_ref)
    case Circuits.I2C.write_read(i2c_ref, @ads1115_addr, <<@reg_conversion>>, 2) do
      {:ok, <<msb, lsb>>} ->
        # Step 1 — Read  the 2 bytes and convert them to one 16-bit unsigned integer.
        #
        # Example: msb = 0x0C = 0000_1100
        #          lsb = 0xD4 = 1101_0100
        #
        # msb <<< 8 shifts msb left by 8 positions:
        #   0000_1100 → 0000_1100_0000_0000 = 0x0C00 = 3072
        # and then OR with lsb:
        # ||| lsb ORs in the low byte:
        #   0000_1100_0000_0000
        # | 0000_0000_1101_0100
        # = 0000_1100_1101_0100 = 0x0CD4 = 3284
        raw = msb <<< 8 ||| lsb

        # Step 2 — Convert unsigned to signed (two's complement).
        #
        # ADS1115 returns signed values. Elixir integers are
        # unsigned by default so we must handle the sign manually.
        #
        # Unsigned 16-bit range: 0      to 65535
        # Signed   16-bit range: -32768 to +32767
        #
        # Any value above 32767 has its sign bit (bit 15) set = negative:
        #   32768 → -32768  (0x8000 → most negative)
        #   65535 → -1      (0xFFFF → minus one)
        #   3284  →  3284   (positive, no change needed)
        #
        # Subtracting 65536 (= 2^16) recovers the correct signed value:
        #   65535 - 65536 = -1     
        #   32768 - 65536 = -32768 
        #   3284  stays as  3284   
        raw = if raw > 32767, do: raw - 65536, else: raw
        
        # We could use the following line too, instead of steps 1 and 2 above 
        # but we chose the manual above for clarity.
        # Note, that we need to include the library Bitwise for this to work
        #<<raw::signed-integer-size(16)>> = <<msb, lsb>> # Elixir does it all in one line

      {:ok, raw}

    {:error, reason} ->
      {:error, reason}
    end

  end

  # We start polling for 20 times every 10 msec
  defp wait_for_ready(ref, address) do
    do_poll(ref, address, 20)
  end

  # Use case with pattern matching. When attempts reach 0, return a timeout error:
  defp do_poll(_ref, _address, 0), do: {:error, :conversion_timeout}

  # Recursive case: Perform the atomic write_read and check the OS bit
  defp do_poll(ref, address, attempts_left) do
    # Atomic operation: sets pointer and reads config in one bus transaction
    case Circuits.I2C.write_read(ref, address, <<@reg_config>>, 2) do
      {:ok, <<msb, _lsb>>} ->
      # Check if bit 7 (Operational Status) is high (1 = ready)
        if (msb &&& 0x80) == 0x80 do
          :ok
        else
          # Still busy: Wait 10ms and decrement the counter
          Process.sleep(10)
          do_poll(ref, address, attempts_left - 1)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

# This is for the correction factor used in the appendinx 2
defp get_correction_factor(temp) do
  #Immediately turn whatever we got into a whole number (Integer)
  # round() works on both floats (22.5 -> 23) and integers (23 -> 23)
  target_temp = round(temp)

  # lookup the @temp_cf_table
  case Map.get(@temp_cf_table, target_temp) do
    # if found, return the number from the look up table
    factor when is_number(factor) -> 
      factor

    # Not in the map (too hot or too cold)
    # for the edges, just return the 2 last extremes known.
    nil ->
      cond do
        target_temp < -10 -> 0.752
        target_temp > 55  -> 1.138
        true              -> 1.0
      end
  end
end


# Final PPM conversion using the differential
#According to the datasheet at 6-3:
#6-3 Temperature compensation
# It is necessary to continuously write the thermistor output into the microprocessor. Inside the
# microprocessor, temperature compensation is carried
# out by using the compensation coefficient table shown in Appendix 2. 
# CO sensitivity at 20˚C (α) is calculate by the following equation:
# α = αt / CF
# where:
# CF = compensation coefficient at t˚ αt = CO sensitivity at t˚C
# 6-4 Calculation of CO concentration
# CO concentration (C) can be calculated by using
# sensor output (Vout), sensor output in clean air (V0),
# CO sensitivity at 20 ˚C (α), and feedback resistor (Rf)
# in the following formula:
# C = (V0 – Vout) / (α × Rf) [Equation 1]
# When high accuracy is required, temperature
# dependency of an op-amp should be considered
  
# Please note, that since we use an non inverting analog setup in our 
# circuits the correct formula for our case is:
# C = (Vout - V0) / (α × Rf) where V0 = Offset voltage at 0 CO ppm

defp convert_to_ppm(differential, temp) do
  cf = get_correction_factor(temp)
  
  # subtract any leftover calibration offset if necessary
  true_signal = differential - (@calibrated_zero_offset * 2)
  
  alpha = (@sensitivity_na_per_ppm * 1.0e-9) * cf

  # Since we can't have "negative" gas, this line ensure that we always sees 0.0 if the air is clean.
  # clamp this to a valid range
  (true_signal / (alpha * @r3_ohms)) |> max(0.0) |> min(10_000.0)
end

end
