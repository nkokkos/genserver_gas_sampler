defmodule GasSensor.HardwareTemp do
  @moduledoc """
  Read the temperature from the rasberry's  pi cpu

  ## Usage

  HardwareTemp.read_cpu_temp();

  """

  require Logger

  @temp_path "/sys/class/thermal/thermal_zone0/temp"

  def read_cpu_temp do
    case File.read(@temp_path) do
      {:ok, raw} ->
        {millidegrees, _} = Integer.parse(String.trim(raw))
        millidegrees / 1000
      {:error, _} -> 
        # Return a fallback for local development
        25.0 
    end
  end

end

