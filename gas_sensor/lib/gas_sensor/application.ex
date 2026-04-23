defmodule GasSensor.Application do
  @moduledoc """
  OTP Application for the Gas Sensor.

  This application manages:
  1. GasSensor.ReadingAgent - Stores latest reading for non-blocking access
  2. GasSensor.History - 24-hour ETS-based circular buffer for time-series data
  3. GasSensor.Sensor - GenServer that reads from ADC via I2C

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
  │ GasSensor.Sensor (GenServer)           │
  │  ├── I2C bus reference                  │
  │  ├── Current PPM state                  │
  │  └── 7-sample window (~1KB)            │
  ├─────────────────────────────────────────┤
  │ GasSensor.ReadingAgent (Agent)         │
  │  └── Current reading map (~200 bytes)   │
  ├─────────────────────────────────────────┤
  │ GasSensor.History (ETS ordered_set)      │
  │  └── 17,280 samples × 52 bytes = ~900KB │
  └─────────────────────────────────────────┘
  ```
  """
  use Application

  @impl true
  def start(_type, _args) do
    # Initialize timestamp module (records boot time, sets up offline tracking)
    GasSensor.Timestamp.init()

    # Get I2C bus from application configuration (defaults to "i2c-1")
    i2c_bus = Application.get_env(:gas_sensor, :i2c_bus, "i2c-1")

    children = [
      #1. Agent starts first. Always available for web requests 
      GasSensor.ReadingAgent

      #2. BMP 280 Genserver. Starts its own I2C connection and provides data 
 
      # Layer 2: History - 24-hour ETS-based circular buffer
      # No dependencies, ~900KB for 17,280 samples
      # Provides time-series data for graphing and analysis
      GasSensor.History,

      # Layer 3: Sensor - only process that touches I2C
      # Depends on ReadingAgent and History (must start after)
      # Pass I2C bus configuration from app config
      # {GasSensor.Sensor, [i2c_bus: i2c_bus]}
    ]

    opts = [strategy: :one_for_one, name: GasSensor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
