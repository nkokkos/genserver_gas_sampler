defmodule GasSensorWeb.Application do
  @moduledoc """
  OTP Application for the Gas Sensor Web Interface.

  This Phoenix application provides a LiveView interface for
  displaying real-time gas sensor readings from the GasSensor OTP app.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      GasSensorWeb.Telemetry,

      # Start the PubSub system
      {Phoenix.PubSub, name: GasSensorWeb.PubSub},

      # Start the Endpoint (http/https)
      GasSensorWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: GasSensorWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GasSensorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
