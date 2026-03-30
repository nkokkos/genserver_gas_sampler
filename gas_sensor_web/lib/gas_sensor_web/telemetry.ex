defmodule GasSensorWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor for metrics and monitoring.
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller for periodic measurements
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Custom sensor metrics
      last_value("gas_sensor.ppm",
        description: "Current gas concentration in PPM"
      ),
      last_value("gas_sensor.status",
        description: "Sensor operational status"
      )
    ]
  end

  defp periodic_measurements do
    [
      # Add periodic measurements here if needed
    ]
  end
end
