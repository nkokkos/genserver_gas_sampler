defmodule GasSensorWeb.SensorLive do
  @moduledoc """
  LiveView for displaying real-time gas sensor readings.

  ## Architecture Note

  This LiveView reads from GasSensor.ReadingAgent, NOT directly from the Sensor GenServer.
  This ensures:
  - Non-blocking reads (no I2C contention)
  - Fast response times
  - Isolation from I2C hardware issues

  The Agent is updated by the GenServer after each I2C reading.

  ## Display

  - Current PPM reading (with visual indicator)
  - Sensor status
  - Sample count
  - Historical data (window of samples)
  - Connection status
  """
  use GasSensorWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Start polling for updates
    if connected?(socket) do
      :timer.send_interval(1000, self(), :update_reading)
    end

    {:ok,
     assign(socket,
       reading: get_sensor_reading(),
       connected: connected?(socket)
     )}
  end

  @impl true
  def handle_info(:update_reading, socket) do
    reading = get_sensor_reading()
    {:noreply, assign(socket, reading: reading)}
  end

  # Reads from Agent - non-blocking, no I2C access
  # This prevents contention with the I2C bus
  defp get_sensor_reading do
    reading = GasSensor.ReadingAgent.get_reading()

    # Ensure we have all expected keys for the template
    %{
      ppm: Map.get(reading, :ppm, 0.0),
      status: Map.get(reading, :status, :not_started),
      window: Map.get(reading, :window, []),
      sample_count: Map.get(reading, :sample_count, 0)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <div class="max-w-4xl mx-auto py-8 px-4">
        <h1 class="text-3xl font-bold text-gray-900 mb-8 text-center">
          Gas Sensor Monitor
        </h1>
        
        <!-- Connection Status -->
        <div class={[
          "rounded-lg p-4 mb-6 text-center font-semibold",
          @connected && "bg-green-100 text-green-800",
          !@connected && "bg-yellow-100 text-yellow-800"
        ]}>
          <%= if @connected do %>
            Live Updates Active
          <% else %>
            Connecting...
          <% end %>
        </div>
        
        <!-- Main Reading Card -->
        <div class="bg-white rounded-lg shadow-lg p-8 mb-6">
          <h2 class="text-lg font-semibold text-gray-600 mb-4">Current Reading</h2>
          
          <div class="text-center">
            <div class={[
              "text-6xl font-bold mb-2",
              get_ppm_color(@reading.ppm)
            ]}>
              <%= Float.round(@reading.ppm, 2) %>
            </div>
            <div class="text-xl text-gray-500">PPM</div>
          </div>
          
          <!-- Status Badge -->
          <div class="mt-6 flex justify-center">
            <span class={[
              "px-4 py-2 rounded-full text-sm font-semibold",
              get_status_class(@reading.status)
            ]}>
              <%= format_status(@reading.status) %>
            </span>
          </div>
        </div>
        
        <!-- Stats Grid -->
        <div class="grid grid-cols-2 gap-4 mb-6">
          <div class="bg-white rounded-lg shadow p-4">
            <div class="text-sm text-gray-500 mb-1">Sample Count</div>
            <div class="text-2xl font-bold text-gray-900">
              <%= @reading.sample_count %>
            </div>
          </div>
          
          <div class="bg-white rounded-lg shadow p-4">
            <div class="text-sm text-gray-500 mb-1">Window Size</div>
            <div class="text-2xl font-bold text-gray-900">
              <%= length(@reading.window) %>
            </div>
          </div>
        </div>
        
        <!-- Recent Samples -->
        <%= if length(@reading.window) > 0 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold text-gray-700 mb-4">Recent Samples (Last 7)</h3>
            <div class="space-y-2">
              <%= for {sample, index} <- Enum.with_index(@reading.window) do %>
                <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                  <span class="text-sm text-gray-600">Sample <%= index + 1 %></span>
                  <span class={["font-semibold", get_ppm_color(sample)]}>
                    <%= Float.round(sample, 2) %> PPM
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
        
        <!-- Auto-refresh indicator -->
        <div class="mt-6 text-center text-sm text-gray-400">
          Updates every second
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for styling
  defp get_ppm_color(ppm) when ppm < 50, do: "text-green-600"
  defp get_ppm_color(ppm) when ppm < 100, do: "text-yellow-600"
  defp get_ppm_color(ppm) when ppm < 200, do: "text-orange-600"
  defp get_ppm_color(_), do: "text-red-600"

  defp get_status_class(:ok), do: "bg-green-100 text-green-800"
  defp get_status_class(:error), do: "bg-red-100 text-red-800"
  defp get_status_class(:not_started), do: "bg-gray-100 text-gray-800"
  defp get_status_class(_), do: "bg-yellow-100 text-yellow-800"

  defp format_status(:ok), do: "Sensor Active"
  defp format_status(:error), do: "Sensor Error"
  defp format_status(:not_started), do: "Sensor Not Started"
  defp format_status(status), do: "Status: #{status}"
end
