# Add your own IEx startup logic here

# Helper module for interactive use
defmodule Sampler.Helpers do
  @moduledoc """
  Helper functions for IEx interactive shell.
  """

  @doc """
  Get the current gas sensor reading from the Agent.

  This is a non-blocking read from the Agent cache.
  """
  def gas_ppm do
    GasSensor.ReadingAgent.get_ppm()
  end

  @doc """
  Get the full gas sensor state from the Agent.

  This is a non-blocking read from the Agent cache.
  """
  def gas_state do
    GasSensor.ReadingAgent.get_reading()
  end

  @doc """
  Print formatted gas sensor information.
  """
  def gas_info do
    reading = gas_state()

    IO.puts("Gas Sensor Information")
    IO.puts("======================")
    IO.puts("Current PPM: #{Float.round(reading.ppm, 2)}")
    IO.puts("Status: #{reading.status}")
    IO.puts("Sample Count: #{reading.sample_count}")
    IO.puts("Window Size: #{length(reading.window)}")
    IO.puts("")
    IO.puts("Raw Samples:")

    Enum.each(reading.window, fn ppm ->
      IO.puts("  - #{Float.round(ppm, 2)} ppm")
    end)

    :ok
  end

  @doc """
  Get web interface URL.
  """
  def web_url do
    # Try to get IP address
    case :inet.getifaddrs() do
      {:ok, ifaddrs} ->
        ips =
          for {_, opts} <- ifaddrs,
              {:addr, addr} <- opts,
              :inet.is_ipv4_address(addr),
              addr != {127, 0, 0, 1} do
            "http://#{:inet.ntoa(addr)}/"
          end

        case ips do
          [] ->
            "No network interface found. Check WiFi configuration."

          urls ->
            IO.puts("Web Interface URLs:")
            Enum.each(urls, &IO.puts("  #{&1}"))
            :ok
        end

      {:error, _} ->
        "Could not determine IP address. Check WiFi with VintageNet.info()"
    end
  end
end

# Print useful information on boot
IO.puts("")
IO.puts("Sampler Nerves Firmware Started")
IO.puts("================================")
IO.puts("")
IO.puts("Applications automatically started:")
IO.puts("  ✓ GasSensor (I2C sensor reading)")
IO.puts("  ✓ GasSensorWeb (Phoenix web interface)")
IO.puts("")
IO.puts("Available helpers:")
IO.puts("  Sampler.Helpers.gas_ppm/0      - Get current PPM from Agent")
IO.puts("  Sampler.Helpers.gas_state/0    - Get full reading from Agent")
IO.puts("  Sampler.Helpers.gas_info/0     - Print formatted sensor info")
IO.puts("  Sampler.Helpers.web_url/0      - Show web interface URL")
IO.puts("")
IO.puts("Architecture:")
IO.puts("  Sensor (I2C) → Agent (cache) ← Phoenix (web)")
IO.puts("")

# Try to print web URL on boot
Sampler.Helpers.web_url()
