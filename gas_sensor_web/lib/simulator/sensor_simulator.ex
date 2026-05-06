defmodule GasSensorWeb.Simulator.SensorSimulator do
  @moduledoc """
  Simulates sensor readings with realistic variation.
  Updates ReadingAgent and History just like real sensor.
  """
  use GenServer
  alias GasSensorWeb.Simulator.{ReadingAgent, History}

  @update_interval 1_000  # 1 second updates

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    initial_state = %{
      base_ppm: 10.0,
      trend: 0.0
  }
    schedule_update()
    {:ok, initial_state}
  end

  def handle_info(:update, state) do
    # Generate realistic sensor reading
    schedule_update()
    new_state = generate_and_update(state)
    {:noreply, new_state}
  end

  defp schedule_update do
    Process.send_after(self(), :update, @update_interval)
  end

  defp generate_and_update(state) do
    # Simulate realistic PPM variation
    # - Base value with slow drift
    # - Random noise
    # - Occasional spikes
    
    drift = :rand.uniform() * 0.5 - 0.25  # ±0.25 per second
    new_trend = state.trend + drift
    new_trend = max(-5.0, min(5.0, new_trend))  # Limit trend
    
    noise = (:rand.uniform() - 0.5) * 2  # ±1 PPM noise
    spike = if :rand.uniform() > 0.95, do: :rand.uniform() * 20, else: 0
    
    ppm = state.base_ppm + new_trend + noise + spike
    ppm = max(0.0, ppm)  # No negative PPM
    
    # Create reading with all fields
    timestamp = DateTime.utc_now()
    
    reading = %{
      co_ppm: ppm,
      temperature_c: 20.0 + :rand.uniform() * 5,
      humidity_rh: 45.0 + :rand.uniform() * 10,
      pressure_pa: 101325.0 + :rand.uniform() * 500,
      dew_point_c: 10.0 + :rand.uniform() * 5,
      gas_resistance_ohms: 50000.0 + :rand.uniform() * 10000,
      cpu_temperature: 31.0 + :rand.uniform() * 5,
      vref: 2.0,
      vsensor: 1.041 + :rand.uniform() * 0.5,
      vsensor_offset: 0.1,
      vdifferential: 0.5,
      vref_variance: 0.01,
    }
    
    # Update Agent
    ReadingAgent.add_sample(reading, :ok)
    
    # Update History (ETS) Note: History update is done from Reading Agent
    # History.record_to_ets(timestamp, reading)
    
    # Return the new state 
    %{state | trend: new_trend} 
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end
end
