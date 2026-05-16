defmodule GasSensorWeb.VsensoroffsetLive do 
  use GasSensorWeb, :live_view

  def mount(_params, _session, socket) do 
   
    # load configuration from file:
    vsensor_offset_value = GasSensor.ConfigManager.init()

    {:ok, 
      socket
      |> assign(:vsensor_offset, vsensor_offset_value) 
      |> assign(:error, nil) # Your existing assign
      |> assign(:connected, connected?(socket))
    }
    end

  def handle_event("save_settings", %{"vsensor_offset" => value}, socket) do 
    case parse_and_validate(value) do 
      {:ok, value} ->
      GasSensor.ConfigManager.save_vsensor_offset(value)
      GasSensor.ReadingAgent.update_vsensor_offset(value)
      {:noreply, assign(socket, vsensor_offset: value, error: nil)}
		 
      {:error, message} ->
        {:noreply, assign(socket, error: message)}
    end
  end 

  defp parse_and_validate(value) do 
    case Float.parse(value) do 
     {num, ""} when num >=0 and num <= 5 ->
       {:ok, num}

     {_num, ""} ->
       {:error, "Value must be between 0 and 5"}

     _ ->  {:error, "Invalid number"}
    end
  end 

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
							  <!-- 1. CLEAN INACTIVE (No border, no background) -->
							  <.link navigate={~p"/sensor/detail"} class="flex items-center gap-3 px-4 py-3 
								text-slate-400 rounded-xl hover:bg-white/5 hover:text-white transition group">
								<span class="font-medium">Live Monitor CO - TEMP </span>
							  </.link>
							  
							  <!-- 2. CLEAN INACTIVE (No border, no background) -->
							  <.link navigate={~p"/sensor/volts"} class="flex items-center gap-3 px-4 py-3 
								text-slate-400 rounded-xl hover:bg-white/5 hover:text-white transition group">
								<span class="font-medium">Sensor PPM vs Volts</span>
							  </.link>
							  
							  	<.link navigate={~p"/sensor/history"} class="flex items-center gap-3 px-4 py-3 
								text-slate-400 rounded-xl hover:bg-white/5 hover:text-white transition group">
								<span class="font-medium">Sensor Data History</span>
								</.link>
								
							  <!-- 3. ACTIVE (Solid background, white text) -->
							  <.link navigate={~p"/sensor/offset"} class="flex items-center gap-3 px-4 py-3 text-white bg-indigo-600 
								rounded-xl shadow-lg shadow-indigo-500/20 transition group">
								<span class="font-medium">Sensor Config</span>
							  </.link>
							</nav>
										
										<div class="p-6">
										  <div class="bg-indigo-500/10 border border-indigo-500/20 rounded-2xl p-4">
											<p class="text-indigo-300 text-xs font-semibold uppercase tracking-wider">Device Status</p>
											<p class="text-white text-sm mt-1">Raspberry Pi Zero W</p>
											<div class="flex items-center gap-2 mt-2">
											  <div class="w-2 h-2 rounded-full bg-green-500"></div>
											  <span class="text-green-400 text-xs font-mono">Uptime: 14d 2h</span>
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
											<p class="text-purple-200 text-lg">Vsensor Offset Calibration</p>
											
										  </div>
											
									<!-- Form Container -->
							<div class="relative group max-w-2xl mx-auto mb-12">
							  <!-- Gradient Border Glow -->
							  <div class="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl blur opacity-30 group-hover:opacity-50 transition"></div>
							  
							  <div class="relative bg-slate-900/80 backdrop-blur-xl rounded-2xl p-8 border border-white/10">
								<h2 class="text-white text-2xl font-bold mb-6 flex items-center gap-2">
								  <span>⚙️</span> Sensor Configuration / Voltage Offset (V)
								</h2>
							     <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
								   <div class="block text-lg font-medium text-purple-200 mb-2">
									 
									</div>
									<% end %>
								<form phx-submit="save_settings" class="space-y-6">
								  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

									<!-- Voltage Offset (Relevant to your ADC calibration) -->
									<div>
									  <label for="offset" class="block text-lg font-medium text-purple-200 mb-2">Voltage Offset (V)</label>
									  <input type="number" step="0.001" id="offset" type="number" 
									   name="vsensor_offset" 
									   value={@vsensor_offset} 
									   min="0"
									   max="5"
									   step="any"
									   required
									   class="w-full bg-slate-950/50 border border-white/10 text-white rounded-xl focus:ring-2 focus:ring-indigo-500 
									   focus:border-transparent p-5 text-xl transition" 
										>
										
										<%= if @error do %>
									      <p class="mt-2 text-sm text-red-400"><%= @error %></p>
										<% end %>
																	     <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
								   <div class="block text-lg font-medium text-purple-200 mb-2">
									 Ok, έγινε η αποθήκευση
									</div>
									<% end %>
									</div>
								  </div>
                                    
								  
								  <!-- Action Button -->
								  <button type="submit" 
									class="w-full py-3 px-6 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white font-bold rounded-xl shadow-lg shadow-indigo-500/25 transition-all transform active:scale-[0.98]">
									Save Offset
								  </button>
								</form>

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
     

