defmodule Firmware.NetworkMonitor do

  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Subscribe to VintageNet's property table
    # Whenever ["interface", "wlan0", "connection"] changes,
    # you'll get a message
    VintageNet.subscribe(["interface", "wlan0", "connection"])
    {:ok, %{}}
  end

  # VintageNet sends you this message when connection goes to :disconnected
  # It checks this every 30 seconds
  def handle_info( {VintageNet, ["interface", "wlan0", "connection"], _old, :disconnected, _meta}, state) do

    Logger.warning("WiFi disconnected, reconfiguring...")
    
    # Load the saved WiFi config from /data
    config = VintageNet.get_configuration("wlan0")
    
    # Reconfigure with same config - this "bounces" the interface
    # Tears down wpa_supplicant and brings it back up
    VintageNet.configure("wlan0", config)
    
    {:noreply, state}
  end

  # When connection status changes to :internet, you get notified
  def handle_info({VintageNet, ["interface", "wlan0", "connection"], _old, :internet, _meta}, state) do
    Logger.info("WiFi reconnected to internet")
    {:noreply, state}
  end

  # Catch-all for any other messages (like :lan state)
  def handle_info(_, state), do: {:noreply, state}

end
