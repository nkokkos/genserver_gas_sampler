defmodule Core.HardwareTemp do
  @moduledoc """
  Read the temperature from the raspberry's pi cpu
  
  The information about /sys/class/thermal/thermal_zone0/temp comes from the Linux Kernel's Thermal Sysfs interface.
  The kernel documentation specifies that temperatures in sysfs are reported in millidegrees Celsius.
  If the file contains 48500, the temperature is exactly 48.5°C.
  https://www.kernel.org/doc/Documentation/driver-api/thermal/sysfs-api.rst

  ## Usage

  HardwareTemp.read_cpu_temp();
  """
  
  require Logger
  
  def read_cpu_temp do

    pi_temp_path = Application.get_env(:gas_sensor, :temp_path)

    if File.exists?(pi_temp_path) do
      # Real hardware logic
      case File.read(pi_temp_path) do
        {:ok, raw} ->
          {millidegrees, _} = Integer.parse(String.trim(raw))
          millidegrees / 1000.0
        _ -> 25.0
      end
    else
      # Fallback for your host development environement like VirtualBox environment
      # This generates a random float between 35.0 and 45.0
      :rand.uniform() * 10 + 35
      |> Float.round(1)
    end
  end

end

