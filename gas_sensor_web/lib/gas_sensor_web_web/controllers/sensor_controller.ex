defmodule GasSensorWeb.SensorController do
  @moduledoc """
  API controller for sensor data.

  ## Architecture Note

  This controller reads from GasSensor.ReadingAgent for non-blocking access
  to the latest sensor reading. This prevents I2C bus contention.
  """
  use GasSensorWeb, :controller

  @doc """
  Returns list of available readings.

  Currently returns a single-item list with the current reading.
  """
  def index(conn, _params) do
    readings = [get_current_reading()]
    json(conn, %{readings: readings})
  end

  @doc """
  Returns the current sensor reading.

  Response includes:
  - ppm: Current CO concentration
  - status: Sensor operational status
  - timestamp: When reading was last updated
  """
  def current(conn, _params) do
    reading = get_current_reading()
    json(conn, reading)
  end

  # Reads from Agent - non-blocking, no I2C access
  defp get_current_reading do
    reading = GasSensor.ReadingAgent.get_reading()

    %{
      ppm: Map.get(reading, :ppm, 0.0),
      status: format_status(Map.get(reading, :status, :not_started)),
      timestamp: Map.get(reading, :timestamp, DateTime.utc_now())
    }
  end

  defp format_status(:ok), do: "ok"
  defp format_status(:error), do: "error"
  defp format_status(:not_started), do: "not_started"
  defp format_status(status), do: to_string(status)
end
