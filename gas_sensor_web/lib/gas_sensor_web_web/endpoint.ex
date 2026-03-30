defmodule GasSensorWeb.Endpoint do
  @moduledoc """
  HTTP Endpoint for the Gas Sensor Web application.

  Configured for embedded deployment on Raspberry Pi Zero W.
  """
  use Phoenix.Endpoint, otp_app: :gas_sensor_web

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  @session_options [
    store: :cookie,
    key: "_gas_sensor_web_key",
    signing_salt: "sensor_salt"
  ]

  # Serve static files from priv/static
  plug(Plug.Static,
    at: "/",
    from: :gas_sensor_web,
    gzip: false,
    only: GasSensorWeb.static_paths()
  )

  # Code reloading for development
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(GasSensorWeb.Router)
end
