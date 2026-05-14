defmodule GasSensor.Sensor do
  @moduledoc """
  GenServer for the TGS5042 Gas Sensor via ADS1115 ADC.

  * Samples @number_of_samples times evenly spread every @sample_interval seconds.
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

  # Detailed Instruction on sampling the ADS1115 ADC:

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
  # We will be sampling at 8 samples per second:
  # At 8 SPS: peak-to-peak noise = 125µV

  # Configuration for the ADS1115 Register Addresses:
  # The ADS1115 has 4 registers. We will use two:
  #   0x00 → Conversion register  — holds the ADC result
  #   0x01 → Config register      — controls all chip settings
  @reg_conversion 0x00
  @reg_config 0x01

  # We will sample the reference voltage of 2Volts at A0 and at A1 the TGS5042 signal voltage
  @config_msb_a0 0xC3     # 1_100_001_1  → OS=1, MUX=AIN0/GND, PGA=±4.096V, single-shot
  @config_msb_a1 0xD3     # 1_101_001_1  → OS=1, MUX=AIN1/GND, PGA=±4.096V, single-shot
  @config_lsb 0x03        # 0_000_0_0_11 → DR=8SPS, comparator disabled

  @volts_per_count 0.000125  # ±4.096V / 32768 counts = 125µV per LSB 

  # ASDS1115 configuration: 
  
  # ADS1115 I2C address
  @ads1115_addr 0x48
  
  # Not used here, since we used the polling technique. 
  # See how we use polling to read the ads1115 chip
  # @conversion_ms 140 # time to wait for the conversion register to get ready

  @sample_interval 15_000 # how often we should we sample the inputs
  @number_of_samples 7    # sample 7 times for the median filter

  # TGS_5042 Sensor calibration: 
  @sensitivity_na_per_ppm 1.525 	# this is the number printed on the module we got.
  @r3_ohms 1_200_000                    # feed back resistor connected to the mcp6042 Op amp
                                        # of 1% sensitivity

  # Temperature compensation table for TGS5042
  # This is based in the application note
  # "APPLICATION NOTES FOR TGS5xxx SERIES" - Revised 12/25
  # Appendix 2 - Temperature Compensation Coefficients for Residential Usage:
  # This is the look up table copied over from the datasheet:

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
 
  # According to the datasheet at 6-3:
  # 6-3 Temperature compensation
  # It is necessary to continuously write the thermistor output into the microprocessor. Inside the
  # microprocessor, temperature compensation is carried
  # out by using the compensation coefficient table shown in Appendix 2. 
  # CO sensitivity at 20˚C (α) is calculate by the following equation:
  # α = αt / CF
  # where:
  # CF = compensation coefficient at t˚ αt = CO sensitivity at t˚C
  # 
  # 6-4 Calculation of CO concentration
  # 
  # CO concentration (C) can be calculated by using
  # sensor output (Vout), sensor output in clean air (V0),
  # CO sensitivity at 20 ˚C (α), and feedback resistor (Rf)
  # in the following formula:
  # C = (V0 – Vout) / (α × Rf) [Equation 1]
  # When high accuracy is required, temperature
  # dependency of an op-amp should be considered
  
  # Final Equation:
  # Note to myself: since we use an non inverting analog setup in our 
  # circuits the correct formula for our case is:
  # C = (Vout - V0) / (α × Rf) where V0 = Offset voltage at 0 CO ppm 

  # Empty Reading Attribute. 
  # Contains all the fields that need to be filled.
  # Use this module attribute as a empty reading 
  # Use it as a blueprint for the beginning of the sampling process
  # or in case of an  error, when it happens, send this over to 
  # the reading agent along with an error.
  @empty_reading %{
    co_ppm: 0.0,
    temperature_c: 0.0,
    humidity_rh: 0.0,
    pressure_pa: 0.0,
    dew_point_c: 0.0,
    gas_resistance_ohms: 0.0,
    cpu_temperature: 0.0,
    vref: 0.0,
    vsensor: 0.0,
    vdifferential: 0.0,
    vsensor_offset: 0.0,
    vref_variance: 0.0
  }

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
        state = 
          @empty_reading
          |> Map.merge(%{i2c: ref})

        # Start first sample immediately
        send(self(), :collect_sample)
        Logger.info("GasSensor started on #{i2c_bus}")
        {:ok, state}

      {:error, reason} ->
        # Error Reason. Use the empty variable and add the reason
        error_reading = 
          @empty_reading
            |> Map.put(:error_message, ":error in GasSensor.Sensor.init(opts): #{inspect(reason)}")

        GasSensor.ReadingAgent.add_sample(error_reading, :error)
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
    
    result = 

       with {:ok, bme680_data } <- BMP280.measure(:bme680),
            _                   <- Process.sleep(1000),
            {:ok, cpu_temp }    <- GasSensor.HardwareTemp.read_cpu_temp(),
            _                   <- Process.sleep(1000),
            {:ok, samples}      <- collect_samples(state.i2c, @number_of_samples) 
       do
        
         differential_list = Enum.map(samples, fn s -> s.differential end)
         vref_list = Enum.map(samples, fn s -> s.vref end)
         vsensor_list = Enum.map(samples, fn s -> s.vsensor end) 

         # calculate the median of each stream of data:
         vref_median = calculate_median(vref_list)
         vsensor_median = calculate_median(vsensor_list)
         vdifferential_median = calculate_median(differential_list)
         vref_variance = variance(vref_list)

         # finally, calculate the ppm for the gas
         final_ppm = convert_to_ppm(vref_median,
                                   vsensor_median, 
                                   bme680_data.temperature_c, 
                                   state.vsensor_offset) 

         # Update the state with all the data, except the 
         # vsensor_offset, which is a default value of 1.0 and then 
         # changed from the settings menu.
          
         # The vsensor_offset value should be set to the value of
         # differential at 0 CO ppm at the settings menu.

         # That is, from the liveview page, at 0 CO ppm, read the 
         # differential and set vsensor_offset = differential at the settings 
         # menu

         new_state = %{ state |
           co_ppm: final_ppm,
           temperature_c: bme680_data.temperature_c,
           humidity_rh: bme680_data.humidity_rh,
           pressure_pa: bme680_data.pressure_pa,
           dew_point_c: bme680_data.dew_point_c,
           gas_resistance_ohms: bme680_data.gas_resistance_ohms,
           cpu_temperature: cpu_temp,
           vref: vref_median,
           vsensor: vsensor_median,
           vdifferential: vdifferential_median,
           vref_variance: vref_variance,
         }
     
         # Update the Agent for non-blocking reads
         # This updates the History too. Read the code of
         # the ReadingAgent to understand more
         GasSensor.ReadingAgent.add_sample(new_state, :ok)
        
         # In Elixir, the last line executed is the return value of the entire block
         # so here, the new_state will be equal to the result above.

         # Note this!! It returns the new_state and it assigns it to result!!! 
         new_state
        else 
          {:error, reason} ->
             Logger.error("GasSensor error with value: #{inspect(reason)}")
             new_state =
               @empty_reading
               |> Map.put(:i2c, state.i2c)  # keep the i2c ref so we can retry next sample
               |> Map.put(:error_message,   ":error GasSensor.Sensor.handle_info: #{inspect(reason)}")
             
             GasSensor.ReadingAgent.add_sample(new_state, :error)  
             #returns the new state and it assigns it to result
             new_state

          unexpected ->
            # This catches everything else 
            Logger.error("GasSensor unexpected with clause value: #{inspect(unexpected)}")
            new_state =
              @empty_reading
              |> Map.put(:i2c, state.i2c)
              |> Map.put(:error_message, "Unexpected value: #{inspect(unexpected)}")

              GasSensor.ReadingAgent.add_sample(new_state, :error)
              # returns new state and assigns it to result
              new_state
       end

       # Schedule next sample
       Process.send_after(self(), :collect_sample, @sample_interval)
       
      {:noreply, result}
  end

  # ── Private Functions ────────────────────────────────────

  defp collect_samples(i2c, n) do
    results = for _ <- 1..n, do: read_ads1115(i2c)

    # Check if any sample failed
    if Enum.all?(results, fn r -> match?({:ok, _}, r) end) do
      # All good — unwrap the :ok tuples into plain maps
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      # Find and return the first error
      Enum.find(results, fn r -> match?({:error, _}, r) end)
    end
  end

  defp read_ads1115(i2c_ref) do 
  
    with {:ok, raw_a0} <- read_channel(@config_msb_a0, i2c_ref),
         {:ok, raw_a1} <- read_channel(@config_msb_a1, i2c_ref) 
    do
      # Convert raw counts to volts
      v_ref    = raw_a0 * @volts_per_count
      v_halved = raw_a1 * @volts_per_count

      # Reconstruct the signal
      # Multiply by 2.0 to reverse the hardware voltage divider I use at the output
      # of the first op amp mcp6042:

      v_op_amp = v_halved * 2.0

      # Calculate differential
      # This removes the ~2.0V bias of the reference singal to isolate the sensor signal
      ratio_zero = v_op_amp / v_ref
      differential = ratio_zero * 2.0 # 2.0 is the nominal reference voltage

      # Return a map containing all three calculated values
      {:ok, %{ differential: differential, vref: v_ref, vsensor: v_op_amp }}
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
  defp read_channel(config_msb, i2c_ref) do 
  
    # Trigger conversion.
    # Write 3 bytes to the chip:
    #   byte 1: reg_config (0x01) → "This is the config register"
    #   byte 2: config_msb        → channel + PGA + single-shot + start
    #   byte 3: config_lsb        → 8 SPS + comparator disabled
    
    # If any step fails, it will bubble the error to the caller
    with :ok <- Circuits.I2C.write(i2c_ref, @ads1115_addr, <<@reg_config, config_msb, @config_lsb>>),
         :ok <- wait_for_ready(i2c_ref, @ads1115_addr),
         {:ok, raw_value} <- read_conversion(i2c_ref) 
    do
      # If everything succeeded, we return the final result
      {:ok, raw_value}
    else
      # If ANY step above returned {:error, reason}, it lands here.
      # We simply pass that error back up the chain.
      {:error, reason} -> {:error, reason}
    end

  end
 

  # ── Read Conversion Result  ────────────────────────────────
  
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
  defp read_conversion(i2c_ref) do 
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

  # We start polling for 20 times every 10 msec, so the maximum
  # time will spend polling would be 200 msec
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
    
    # Immediately turn whatever we got into a whole number (Integer)
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


  # "APPLICATION NOTES FOR TGS5xxx SERIES" - Revised 12/25

  # According to the datasheet at 6-3:
  # 6-3 Temperature compensation
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
  
  # We should use a ratiometric approach since the 5 volts supplying 
  # the 2 volts reference and the op amp is the same.
  # If there is change in Vref, then it should affect the Vsensor too.
  # By doing ratiometric work, we eliminate the fluctuations.

  defp convert_to_ppm(vref, vsensor, temp, vsensor_offset) do
    
    # get the correction factor for the look up table
    cf = get_correction_factor(temp)

    # calculate ratio of the 2 values
    ratio = vsensor / vref 
    vout = ratio * 2.0 # 2 volts nominal voltage
    
    # calculate delta and alpha according to the data sheet
    delta = vout - vsensor_offset 
    alpha = (@sensitivity_na_per_ppm * 1.0e-9) * cf

    # Since we can't have "negative" gas, this line ensures that we always 
    # see 0.0 if the air is clean.
    # clamp this to a valid range between 0.0 and 10000
    (delta / (alpha * @r3_ohms)) |> max(0.0) |> min(10_000.0)
  end

  # Variance - This calculates the variance of the elements in a list
  # Here, we use this to calculate the variance of the Vref signal to 
  # to see if the reference voltages gets degrated over time.
  # The closer we are to 0 the better we are. It calcualates 
  defp variance(list) do
    mean = Enum.sum(list) / length(list)
    Enum.map(list, fn x -> (x - mean) * (x - mean) end)
    |> Enum.sum()
    |> Kernel./(length(list))
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
  # Calculates the median given a list=values
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
