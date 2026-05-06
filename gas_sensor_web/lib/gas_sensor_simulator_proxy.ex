# This defines GasSensor at the root level so the LiveView can find it
defmodule GasSensor do
  defmodule ReadingAgent do
    # This points the global call to your specific Simulator
    defdelegate get_reading(), to: GasSensorWeb.Simulator.ReadingAgent
    defdelegate get_ppm(), to: GasSensorWeb.Simulator.ReadingAgent
    defdelegate get_status(), to: GasSensorWeb.Simulator.ReadingAgent
  end

  defmodule History do
    defdelegate get_for_graph(max_points), to: GasSensorWeb.Simulator.History
    defdelegate get_last_24h(), to: GasSensorWeb.Simulator.History
  end
end
