defmodule GasSensorWeb.SensorHistoryLive do
  @moduledoc """
  Just 2 hours history & 24 hours history
  """
  use GasSensorWeb, :live_view

  @current_refresh 1_000   # 1 second
  @history_refresh 5_000   # 5 seconds
  @history_seconds 300     # 5 minutes
  @history_1_minute 60     # 1 minute
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      #:timer.send_interval(@current_refresh, self(), :update_current)
      #:timer.send_interval(@history_refresh, self(), :update_history)
      #:timer.send_interval(@history_refresh, self(), :update_history_1_minute)
    end

    {:ok,
     socket
     #|> assign(:current, get_current())
     #|> assign(:history, get_history())
     #|> assign(:history_1_minute, get_history_1_minute())
     |> assign(:history_2_hours, get_last_2_hours())
     |> assign(:connected, connected?(socket))}
  end

  @impl true
  def handle_info(:update_current, socket) do
    {:noreply, assign(socket, :current, get_current())}
  end

  @impl true
  def handle_info(:update_history, socket) do
    {:noreply, assign(socket, :history, get_history())}
  end

  @impl true
  def handle_info(:update_history_1_minute, socket) do
    {:noreply, assign(socket, :history_1_minute, get_history_1_minute())}
  end
  
  #this reads from the agent
  defp get_current do
    GasSensor.ReadingAgent.get_reading()
  end
  
  # should show CO, temperature, humidity 
  defp get_last_2_hours do
    {now, _} = GasSensor.Timestamp.now_with_reliability()
    cutoff = DateTime.add(now, -7200, :second)
    
    GasSensor.History.get_since(cutoff)
    |> Enum.map(fn reading ->
      %{
        time: format_time(reading.timestamp),
        co_ppm: reading.co_ppm,
        temperature: reading.temperature_c
      }
    end)
  
  end

  defp get_history_7_days_graph do 
  
  end

  defp get_history do
    {now, _} = GasSensor.Timestamp.now_with_reliability()
    cutoff = DateTime.add(now, -@history_seconds, :second)
    
    GasSensor.History.get_since(cutoff)
    |> Enum.map(fn reading ->
      %{
        time: format_time(reading.timestamp),
        co_ppm: reading.co_ppm,
        temperature: reading.temperature_c
      }
    end)
  end
  
  defp get_history_1_minute do 
   {now, _} = GasSensor.Timestamp.now_with_reliability()
    cutoff = DateTime.add(now, -@history_1_minute, :second)
    
    GasSensor.History.get_since(cutoff)
    |> Enum.map(fn reading ->
      %{
        time: format_time(reading.timestamp),
        co_ppm: reading.co_ppm,
        temperature: reading.temperature_c
      }
    end)
  end

  defp format_time(%DateTime{} = ts) do
    Calendar.strftime(ts, "%H:%M:%S")
  end

  defp get_co_status(ppm) when ppm < 50, do: {:safe, "Safe", "text-green-600"}
  defp get_co_status(ppm) when ppm < 100, do: {:moderate, "Moderate", "text-yellow-600"}
  defp get_co_status(_), do: {:high, "High Alert", "text-red-600"}

  defp get_temp_class(temp) when temp < 25, do: "text-blue-600"
  defp get_temp_class(temp) when temp < 30, do: "text-green-600"
  defp get_temp_class(_), do: "text-orange-600"

  @impl true
  def render(assigns) do
    ~H"""
			<div class="flex min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
		  <!-- Sidebar -->
		  <aside class="w-72 hidden md:flex flex-col flex-shrink-0 border-r border-white/10 bg-slate-950/40 backdrop-blur-xl">
			<div class="p-8 flex items-center gap-3">
			  <div class="w-8 h-8 rounded-lg bg-indigo-500 flex items-center justify-center shadow-lg shadow-indigo-500/50">
				<span class="text-white font-bold">T</span>
			  </div>
			  <span class="text-white font-bold text-xl tracking-tight">SensorHub</span>
			</div>
			
							
				<nav class="flex-1 px-4 space-y-2">
				  <!-- 1. inactive (No border, no background) -->
				  <.link navigate={~p"/sensor/detail"} class="flex items-center gap-3 px-4 py-3 
					text-slate-400 rounded-xl hover:bg-white/5 hover:text-white transition group">
					<span class="font-medium">Live Monitor CO - TEMP </span>
				  </.link>
				  
				  <!--INACTIVE (No border, no background) -->
				  <.link navigate={~p"/sensor/volts"} class="flex items-center gap-3 px-4 py-3 
					text-slate-400 rounded-xl hover:bg-white/5 hover:text-white transition group">
					<span class="font-medium">Sensor PPM vs Volts</span>
				  </.link>
				   
				   <!-- active (Solid background, white text) -->
				  <.link navigate={~p"/sensor/history"} class="flex items-center gap-3 px-4 py-3 text-white bg-indigo-600 
					rounded-xl shadow-lg shadow-indigo-500/20 transition group">
					<span class="font-medium">Sensor Data History</span>
				  </.link>
				  
				  <!-- inactive (Solid background, white text) -->
				  <.link navigate={~p"/sensor/offset"} class="flex items-center gap-3 px-4 py-3 
					text-slate-400 rounded-xl hover:bg-white/5 hover:text-white transition group">
					<span class="font-medium">Sensor Config</span>
				  </.link>
				</nav>
			
			
			
			
			<div class="p-6">
			  <div class="bg-indigo-500/10 border border-indigo-500/20 rounded-2xl p-4">
				<p class="text-indigo-300 text-xs font-semibold uppercase tracking-wider">Device Status</p>
				<p class="text-white text-sm mt-1">Raspberry Pi Zero W</p>
				<div class="flex items-center gap-2 mt-2">
				  <div class="w-2 h-2 rounded-full bg-green-500"></div>
				  <!-- <span class="text-green-400 text-xs font-mono">Uptime..</span> -->
				</div>
			  </div>
			</div>
		  </aside>
			 
		  <!-- Main Content Area -->
		  <main class="flex-1 h-screen overflow-y-auto overflow-x-hidden">
			<!-- <div class="max-w-7xl mx-auto px-4 py-8 lg:px-8"> remove this to me the page wider-->
			  <div class="w-full px-6 py-8">
			  <!-- Header -->
			  <div class="text-center mb-8">
				<div class="inline-flex items-center gap-3 mb-4">
				  <div class="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
				  <h1 class="text-3xl font-bold text-white">TGS5042 CO Sensor</h1>
				</div>
				<p class="text-purple-200 text-sm">Real-time Carbon Monoxide Monitoring</p>
				<%= if @connected do %>
				  <p class="text-green-400 text-sm mt-2">● Live</p>
				<% else %>
				  <p class="text-yellow-400 text-sm mt-2">○ Connecting...</p>
				<% end %>
			  </div>
				
			  <!-- Current Readings -->
			  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
				<!-- CO Card -->
				
				
				
			  </div>
			  
			  			  <!-- Chart Section -->
			  <div class="relative group mb-12">
				<div class="absolute -inset-0.5 bg-gradient-to-r from-purple-600 to-pink-600 rounded-2xl blur opacity-50"></div>
				<div class="relative bg-slate-800 rounded-2xl p-8">
				  <div class="flex items-center justify-between mb-6">
					<div>
					  <h2 class="text-white text-2xl font-bold">2 Hours Trend - CO and Temperature </h2>
					  <p class="text-purple-300 text-sm mt-1">
						<%= length(@history_2_hours) %> data points 
					  </p>
					</div>
					<div class="flex gap-4 text-sm">
					  <div class="flex items-center gap-2">
						<div class="w-4 h-1 bg-red-500 rounded"></div>
						<span class="text-gray-300">CO PPM</span>
					  </div>
					  <div class="flex items-center gap-2">
						<div class="w-4 h-1 bg-blue-500 rounded"></div>
						<span class="text-gray-300">Temp</span>
					  </div>
					</div>
				  </div>
				  <div class="bg-slate-900 rounded-xl p-6">
					<div style="height: 620px; position: relative; width: 100%;">
					  <canvas 
						 id="sensorChart" 
						 phx-hook="SensorChartHistory_2Hours" 
						 class={if length(@history_2_hours) == 0, do: "hidden", else: ""}
						 data-history-hours2={Jason.encode!(@history_2_hours)} 
						 phx-update="ignore">
					   </canvas>
					 </div>
					 
				  </div>
				</div>
			  </div>
			  			
				
			  <!-- Safety Reference -->
			  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-12">
				<div class="bg-slate-800/50 rounded-xl p-4 border border-green-500/30">
				  <div class="text-green-400 font-bold text-lg">&lt; 50 PPM</div>
				  <div class="text-gray-400 text-xs mt-1">Normal air quality</div>
				</div>
				<div class="bg-slate-800/50 rounded-xl p-4 border border-yellow-500/30">
				  <div class="text-yellow-400 font-bold text-lg">50-100 PPM</div>
				  <div class="text-gray-400 text-xs mt-1">Monitor closely</div>
				</div>
				<div class="bg-slate-800/50 rounded-xl p-4 border border-red-500/30">
				  <div class="text-red-400 font-bold text-lg">&gt; 100 PPM</div>
				  <div class="text-gray-400 text-xs mt-1">Ventilate area</div>
				</div>
			  </div>
				
			  <!-- Footer -->
			  <div class="text-center pb-8 text-gray-500 text-xs">
				<p>Figaro TGS5042 Electrochemical CO Sensor</p>
			  </div>
			</div>
		  </main>
		</div>
    """
  end
end
