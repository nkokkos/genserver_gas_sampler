# Configuration for the Raspberry Pi Zero (target rpi0)

import Config

# This is the configuration imported at application.ex

# Delux uses a slot system to prevent different parts of your code fighting for the LED
# :user_feedback (Highest Priority): Temporary blips, like acknowledging a button press. It "covers up" anything below it until it's finished.
# :notification (Medium Priority): Transient alerts that need attention (e.g., an error occurred).
# :status (Lowest Priority): The background state (e.g., "I'm alive" or "Searching for WiFi").

# On the Raspberry Pi Zero, the ACT LED is the small green light near the micro-USB power port.
# By default, Linux uses it to show SD card activity. In Nerves, we take control of it so it 
# can communicate your application's health and logic.


config :firmware,
  indicators: %{
    onboard_led: %{ # name for the LED group
      green: "ACT"  # Tells Delux to control the physical ACT LED
    }
  }

