defmodule GasSensorWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView showing overview of all sensors.

  ## Architecture Note

  This LiveView reads from:
  - GasSensor.ReadingAgent (current reading)
  - GasSensor.History (24-hour time-series data)

  This ensures:
  - Non-blocking reads (no I2C contention)
  - Fast response times
  - 24-hour history for trend analysis
  - Isolation from I2C hardware issues

  ## Data Flow

  ```
  I2C Sensor ──→ GenServer ──→ Agent (current)
                          └──→ History (24h ETS)
                                  │
                                  ↓
                          LiveView (dashboard)
                          ├─ Current value (1s refresh)
                          └─ 24h graph (5s refresh)
  ```
  """
  use GasSensorWeb, :live_view

  # Refresh intervals
  # 1 second for current value
  @current_refresh 1_000
  # 5 seconds for history graph
  @history_refresh 5_000
  # Max points to render (performance)
  @graph_max_points 300

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Start refresh timers
      :timer.send_interval(@current_refresh, self(), :update_current)
      :timer.send_interval(@history_refresh, self(), :update_history)
    end

    {:ok,
     assign(socket,
       reading: get_reading(),
       history: get_history(),
       history_stats: get_history_stats(),
       connected: connected?(socket)
     )}
  end

  @impl true
  def handle_info(:update_current, socket) do
    {:noreply, assign(socket, reading: get_reading())}
  end

  @impl true
  def handle_info(:update_history, socket) do
    {:noreply,
     assign(socket,
       history: get_history(),
       history_stats: get_history_stats()
     )}
  end

  # Reads current value from Agent - O(1), non-blocking
  defp get_reading do
    reading = GasSensor.ReadingAgent.get_reading()

    %{
      ppm: Map.get(reading, :ppm, 0.0),
      status: Map.get(reading, :status, :not_started),
      window: Map.get(reading, :window, []),
      sample_count: Map.get(reading, :sample_count, 0),
      timestamp: Map.get(reading, :timestamp)
    }
  end

  # Reads 24-hour history and downsamples for display
  defp get_history do
    GasSensor.History.get_for_graph(@graph_max_points)
    |> Enum.map(fn %{timestamp: ts, ppm: ppm, status: status} ->
      %{
        time: format_time(ts),
        ppm: ppm,
        status: status,
        color: get_status_color(status, ppm)
      }
    end)
  end

  # Gets statistics for 24-hour period
  defp get_history_stats do
    GasSensor.History.get_stats_24h()
  end

  # Format time for display (HH:MM)
  defp format_time(%DateTime{} = ts) do
    ts
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end

  defp format_time(_), do: "--:--"

  defp get_status_color(:ok, ppm) when ppm < 50, do: "#16a34a"
  defp get_status_color(:ok, ppm) when ppm < 100, do: "#ca8a04"
  defp get_status_color(:ok, _), do: "#dc2626"
  defp get_status_color(_, _), do: "#9ca3af"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div class="max-w-6xl mx-auto py-12 px-4">
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            Gas Sensor Dashboard
          </h1>
          <p class="text-gray-600">24-hour air quality monitoring</p>
        </div>
        
        <!-- Top Row: Current Reading + Stats -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          
          <!-- Current Reading Card -->
          <div class="bg-white rounded-2xl shadow-xl overflow-hidden">
            <div class="bg-gradient-to-r from-indigo-500 to-purple-600 p-6">
              <h2 class="text-white text-lg font-semibold">Current Reading</h2>
            </div>
            
            <div class="p-8">
              <div class="flex items-center justify-between mb-8">
                <div>
                  <div class={["text-6xl font-bold", get_color_class(@reading.ppm)]}>
                    <%= Float.round(@reading.ppm, 1) %>
                  </div>
                  <div class="text-xl text-gray-500 mt-1">PPM</div>
                </div>
                
                <div class={[
                  "w-24 h-24 rounded-full flex items-center justify-center text-2xl",
                  get_circle_class(@reading.ppm)
                ]}>
                  <%= get_emoji(@reading.ppm) %>
                </div>
              </div>
              
              <div class="text-center">
                <span class={[
                  "px-4 py-2 rounded-full text-sm font-semibold",
                  get_status_badge_class(@reading.status)
                ]}>
                  <%= format_status(@reading.status) %>
                </span>
              </div>
            </div>
          </div>
          
          <!-- 24-Hour Statistics Card -->
          <div class="bg-white rounded-2xl shadow-xl overflow-hidden">
            <div class="bg-gradient-to-r from-green-500 to-teal-600 p-6">
              <h2 class="text-white text-lg font-semibold">24-Hour Statistics</h2>
            </div>
            
            <div class="p-6">
              <div class="grid grid-cols-2 gap-4">
                <div class="bg-gray-50 rounded-lg p-4 text-center">
                  <div class="text-3xl font-bold text-gray-800">
                    <%= Float.round(@history_stats.avg, 1) %>
                  </div>
                  <div class="text-sm text-gray-500">Average PPM</div>
                </div>
                
                <div class="bg-gray-50 rounded-lg p-4 text-center">
                  <div class="text-3xl font-bold text-gray-800">
                    <%= @history_stats.count %>
                  </div>
                  <div class="text-sm text-gray-500">Total Samples</div>
                </div>
                
                <div class="bg-gray-50 rounded-lg p-4 text-center">
                  <div class="text-3xl font-bold text-green-600">
                    <%= Float.round(@history_stats.min, 1) %>
                  </div>
                  <div class="text-sm text-gray-500">Minimum</div>
                </div>
                
                <div class="bg-gray-50 rounded-lg p-4 text-center">
                  <div class="text-3xl font-bold text-red-600">
                    <%= Float.round(@history_stats.max, 1) %>
                  </div>
                  <div class="text-sm text-gray-500">Maximum</div>
                </div>
              </div>
              
              <div class="mt-4 pt-4 border-t border-gray-200 text-center text-sm text-gray-500">
                <%= if @history_stats.count > 0 do %>
                  Range: <%= Float.round(@history_stats.max - @history_stats.min, 1) %> PPM
                <% else %>
                  Collecting data...
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 24-Hour Graph -->
        <div class="bg-white rounded-2xl shadow-xl overflow-hidden mb-6">
          <div class="bg-gradient-to-r from-blue-500 to-cyan-600 p-6 flex justify-between items-center">
            <h2 class="text-white text-lg font-semibold">24-Hour Trend</h2>
            <span class="text-white text-sm opacity-75">
              <%= length(@history) %> points • Updated every 5s
            </span>
          </div>
          
          <div class="p-6">
            <%= if length(@history) > 1 do %>
              <div id="history-chart" style="width: 100%; height: 300px;">
                <canvas id="ppmChart"></canvas>
              </div>
              
              <!-- Threshold Legend -->
              <div class="mt-4 flex justify-center gap-6 text-sm">
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded bg-green-500"></div>
                  <span class="text-gray-600">Safe (&lt;50)</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded bg-yellow-500"></div>
                  <span class="text-gray-600">Moderate (50-100)</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded bg-red-500"></div>
                  <span class="text-gray-600">High (&gt;100)</span>
                </div>
              </div>
            <% else %>
              <div class="text-center py-12 text-gray-400">
                <div class="text-4xl mb-2">📊</div>
                <p>Collecting 24-hour data...</p>
                <p class="text-sm mt-2">Check back in a few minutes</p>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- Quick Reference -->
        <div class="grid grid-cols-3 gap-4 mb-6">
          <div class="p-4 bg-gray-50 rounded-lg text-center border-2 border-green-200">
            <div class="text-2xl font-bold text-green-600">&lt;50</div>
            <div class="text-sm text-gray-500">Good</div>
          </div>
          <div class="p-4 bg-gray-50 rounded-lg text-center border-2 border-yellow-200">
            <div class="text-2xl font-bold text-yellow-600">50-100</div>
            <div class="text-sm text-gray-500">Moderate</div>
          </div>
          <div class="p-4 bg-gray-50 rounded-lg text-center border-2 border-red-200">
            <div class="text-2xl font-bold text-red-600">&gt;100</div>
            <div class="text-sm text-gray-500">Unhealthy</div>
          </div>
        </div>
        
        <!-- Navigation -->
        <div class="flex justify-center gap-4 mb-8">
          <.link navigate={~p"/sensor"} class="inline-block bg-indigo-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-indigo-700 transition">
            Detailed View &rarr;
          </.link>
          <%!-- TODO: Add /history route for full 24h data table view --%>
        </div>
        
        <!-- Footer -->
        <div class="mt-12 text-center text-gray-400 text-sm">
          <p>GasSensor Nerves Application • Raspberry Pi Zero W • 24-Hour Memory</p>
          <%= if @connected do %>
            <p class="text-green-500 mt-1">● Live updates active</p>
          <% else %>
            <p class="text-yellow-500 mt-1">○ Connecting...</p>
          <% end %>
        </div>
      </div>
    </div>

    <%= if length(@history) > 1 do %>
      <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
      <script>
        (function() {
          const ctx = document.getElementById('ppmChart').getContext('2d');
          const data = <%= raw(Jason.encode!(@history)) %>;
          
          new Chart(ctx, {
            type: 'line',
            data: {
              labels: data.map(d => d.time),
              datasets: [{
                label: 'PPM',
                data: data.map(d => d.ppm),
                borderColor: '#4f46e5',
                backgroundColor: 'rgba(79, 70, 229, 0.1)',
                borderWidth: 2,
                pointRadius: 1,
                pointHoverRadius: 4,
                fill: true,
                tension: 0.4
              }]
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              interaction: {
                mode: 'index',
                intersect: false
              },
              plugins: {
                legend: { display: false },
                tooltip: {
                  callbacks: {
                    label: function(context) {
                      return 'PPM: ' + context.parsed.y.toFixed(1);
                    }
                  }
                }
              },
              scales: {
                x: {
                  display: true,
                  title: { display: true, text: 'Time (24h)' },
                  ticks: { maxTicksLimit: 8 }
                },
                y: {
                  display: true,
                  title: { display: true, text: 'PPM' },
                  beginAtZero: true,
                  suggestedMax: 100
                }
              }
            }
          });
        })();
      </script>
    <% end %>
    """
  end

  # Helper functions
  defp get_color_class(ppm) when ppm < 50, do: "text-green-600"
  defp get_color_class(ppm) when ppm < 100, do: "text-yellow-600"
  defp get_color_class(_), do: "text-red-600"

  defp get_circle_class(ppm) when ppm < 50, do: "bg-green-100 text-green-600"
  defp get_circle_class(ppm) when ppm < 100, do: "bg-yellow-100 text-yellow-600"
  defp get_circle_class(_), do: "bg-red-100 text-red-600"

  defp get_emoji(ppm) when ppm < 50, do: "✓"
  defp get_emoji(ppm) when ppm < 100, do: "⚠"
  defp get_emoji(_), do: "✕"

  defp get_status_badge_class(:ok), do: "bg-green-100 text-green-800"
  defp get_status_badge_class(:error), do: "bg-red-100 text-red-800"
  defp get_status_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp format_status(:ok), do: "Sensor Active"
  defp format_status(:error), do: "Sensor Error"
  defp format_status(:not_started), do: "Starting..."
  defp format_status(status), do: "Status: #{status}"
end
