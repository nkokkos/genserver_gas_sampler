defmodule GasSensor.Application do
  @moduledoc """
  OTP Application for the Gas Sensor.

  This application manages:
  1. GasSensor.ReadingAgent - Stores latest reading for non-blocking access
  2. GasSensor.History 	    - 7 days ETS-based circular buffer for time-series data
  3. GasSensor.Sensor 	    - GenServer that reads from ADC via I2C

  ## Architecture

  The supervision tree is designed to prevent I2C contention:

  1. ReadingAgent starts first (no dependencies)
  2. History starts second (ETS table, no dependencies)
  3. Sensor GenServer starts third, updates both after each reading
  4. External consumers read from Agent (current) or History (time-series)

  This ensures only one process (the Sensor) ever accesses the I2C bus,
  while providing fast, non-blocking reads for the web interface.

  ## Time Handling (RTC-less Systems)

  Raspberry Pi Zero W has no real-time clock (RTC). The `GasSensor.Timestamp`
  module provides reliable UTC timestamps that detect when NTP hasn't synced
  yet (system time shows 1970 or firmware build date). All timestamps use
  this module to ensure accuracy once NTP synchronizes.

  """
  
  use Application

  # Add build date to the firmware:
  # Note: when you do: mix firmware, build_date will be burned into the .beam file
  # so this will be true after compilation: GasSensor.Application.build_date()
  # This will be set the date we ran "mix firmware"
 
  @build_date DateTime.utc_now() 
  def build_date, do: @build_date  # expose it as a public function so you can call it as:
                                   # Application.build_date

  # grab the real sensor from the config: 
  @bme680 Application.get_env(:gas_sensor, :bme680_module, BMP280)
 
  @impl true 
  def start(_type, _args) do

    # Capture the monotonic zero point at runtime — in this BEAM instance.
    # Used by Timestamp.provisional_timestamp/0 to compute elapsed seconds since boot.
    Application.put_env(:gas_sensor, :boot_monotonic, System.monotonic_time(:second))
  
    # Get I2C bus from application configuration (defaults to "i2c-1")
    # If you are on dev mode on host, i2c_bus will be i2c_bus_stub
    i2c_bus = Application.get_env(:gas_sensor, :i2c_bus, "i2c-1")

    # Provision for real vs fake bme680 sensor. Build the child_spec for the genserver api
    bme680_sensor =
      if @bme680 == BMP280 do # real sensor, we are connected to rpi0 and the breakout is on

        # remember from documentation:
        # https://github.com/elixir-sensors/bmp280
        # {:ok, bmp} = BMP280.start_link(bus_name: "i2c-1", bus_address: 0x77)
        # start real genserver embedded in the library of bmp280:
        # This is a child spec — 
        # that is, it is an instruction you give to the supervisor for how to start a process.
        # It's a tuple with two parts:
        # So, in any part of the codebase you can access the sensor like this:
        # {:ok, data} = BMP280.measure(bmp)
        # where bpm is is pid or the name of the process
        # Access:
        # data.temperature_c      # Temperature in Celsius
        # data.pressure_pa        # Pressure in Pascals
        # data.humidity_rh        # Humidity (if BME280/BME680)

        # therefore, to get readings from this sensor:
        # {:ok, data} = BMP280.measure(:bme680)

        # Start the BMP280 Genserver:
        { 
          BMP280,            # the module to start 
          bus_name: i2c_bus, # the I2C bus name
          i2c_address: 0x77, # the i2c address
          name: :bme680      # pick up a name for the genserver process
        }
       # and below when you call Supervisor.start_link(children, opts)
       # you start the genserver for this module
      else
        # grab the fake stubbed sensor : GasSensor.BME680.Stub
        %{
           id: GasSensor.BME680_Stub,                   # A unique name for the supervisor to track
           start: {GasSensor.BME680_Stub, :start_link, []}, # {Module, Function, [Args]}
           type: :worker,                           # It's a worker, not another supervisor
           restart: :permanent,                     # Restart it if it crashes
           shutdown: 500                            # Give it 500ms to clean up on exit
         }
      end
 
    children = [
       
      # reading agent agent:
      %{
        id: GasSensor.ReadingAgent,              # A unique name for the supervisor to track
        start: {GasSensor.ReadingAgent, :start_link, []}, # {Module, Function, [Args]}
        type: :worker,                           # It's a worker, not another supervisor
        restart: :permanent,                     # Restart it if it crashes
        shutdown: 500                            # Give it 500ms to clean up on exit
      },

      # Start the BMP280 Genserver for reading the BMP680 breakout board:
      bme680_sensor,
     
      # Start the History Genserver which is responsible to saving 
      # historical data
      %{
        id: GasSensor.History,              	 # A unique name for the supervisor to track
        start: {GasSensor.History, :start_link, []}, # {Module, Function, [Args]}
        type: :worker,                           # It's a worker, not another supervisor
        restart: :permanent,                     # Restart it if it crashes
        shutdown: 500                            # Give it 500ms to clean up on exit
      },
 
      # Start Simulator for dev mode. This should commented during
      # during real production 
      #GasSensorWeb.Simulator.SensorSimulator,
   
      # Start the main sensor server. Must be enabled during real production:
      #{GasSensor.Sensor, [i2c_bus: i2c_bus] }, 
      
      # Start telemetry genserver for data upload:
      #{ GasSensor.TelemetryThingsboard, []}
    ]

    opts = [strategy: :one_for_one, name: GasSensor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
