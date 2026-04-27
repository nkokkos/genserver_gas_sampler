defmodule Core.Application do
  @moduledoc """
  OTP Application for the Gas Sensor.

  This application manages:
  1. Core.ReadingAgent - Stores latest reading for non-blocking access
  2. Core.History - 24-hour ETS-based circular buffer for time-series data
  3. Core.Sensor - GenServer that reads from ADC via I2C

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

  ## Memory Layout

  ```
  ┌─────────────────────────────────────────┐
  │ GasSensor.Sensor (GenServer)            │
  │  ├── I2C bus reference                  │
  │  ├── Current PPM state                  │
  │  └── 11-sample window (~1KB)            │
  ├─────────────────────────────────────────┤
  │ GasSensor.ReadingAgent (Agent)          │
  │  └── Current reading map (~200 bytes)   │
  ├─────────────────────────────────────────┤
  │ GasSensor.History (ETS ordered_set)     │
  │  └── 17,280 samples × 52 bytes = ~900KB │
  └─────────────────────────────────────────┘
  ```
  """
  use Application

  # grab the real sensor from the config
  # if we compile on host, use the fake sensor 
  @bme680 Application.compile_env(:gas_sensor, :bme680_module)

  @impl true
  def start(_type, _args) do

    # Provision for real vs fake bme680 sensor
    bme680_sensor =
      if @bme680 == BMP280 do
        # remember from documentation:
        # https://github.com/elixir-sensors/bmp280
        # {:ok, bmp} = BMP280.start_link(bus_name: "i2c-1", bus_address: 0x77)
        # start real genserver embedded in the library of bmp280:
        # This is a child spec — 
        # that is, it is an instruction you give to the supervisor for how to start a process.
        # It's a tuple with two parts:
        # So, in any part of the codebase you can access the sensor like this:
        # {:ok, data} = BMP280.measure(:bme680)
        # Access:
        # data.temperature_c      # Temperature in Celsius
        # data.pressure_pa        # Pressure in Pascals
        # data.humidity_rh        # Humidity (if BME280/BME680)
        { 
          BMP280, # the module to start 
          bus_name: "i2c-1", 
          bus_address: 0x77, 
          name: :bme680 # the options you pass to the module 
        }
       # and below when you call Supervisor.start_link(children, opts)
       # you start the genserver for this module
      else
        @bme680 # grab the fake stubbed sensor : GasSensor.BME680.Stub
      end

    # Initialize timestamp module (records boot time, sets up offline tracking)
    GasSensor.Timestamp.init()

    # Get I2C bus from application configuration (defaults to "i2c-1")
    # If you are on dev mode on host, i2c_bus will be i2c_bus_stub
    i2c_bus = Application.get_env(:gas_sensor, :i2c_bus, "i2c-1")

    children = [

      #1. Agent starts first. Always available for web requests 
      Core.ReadingAgent,

      #2. Start BMP280 Genserver
      #bme680_sensor,
     
      #3. Start History Genserver 
      #Core.History,

      #4. Sensor - only process that touches I2C
      # Depends on ReadingAgent and History (must start after)
      # Pass I2C bus configuration from app config
      # {Core.Sensor, [i2c_bus: i2c_bus]}
    ]

    opts = [strategy: :one_for_one, name: GasSensor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
