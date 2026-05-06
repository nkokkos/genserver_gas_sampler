# Configuration for the Raspberry Pi Zero (target rpi0)

import Config

# On the Raspberry Pi Zero, the ACT LED is the small green light near the micro-USB power port.
# By default, Linux uses it to show SD card activity. In Nerves, we take control of it so it 
# can communicate your application's health and logic.

# This does not work for the indicators and delux.Leave it here for the time being.
# Just look in the application.ex file for more.
config :firmware,
  indicators: %{
    onboard_led: %{ # name for the LED group
      green: "ACT"  # Tells Delux to control the physical ACT LED
    }
  }

# https://elixirforum.com/t/independent-applications-as-local-dependencies/57109/3
# these keys will be available to rpi0 or real firmware on a real device
# Note that temp_path refers to a real path on the rasberry pi zero wireless
config :gas_sensor,
  i2c_bus: "i2c-1",
  bme680_module: BMP280,
  temp_path: "/sys/class/thermal/thermal_zone0/temp",
  env: :target #this is for picking the correct time if we are running on rasberry pi. Look inside the GasSensor.Timestamp module
