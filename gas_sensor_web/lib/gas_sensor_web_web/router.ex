defmodule GasSensorWeb.Router do
  @moduledoc """
  Router for the Gas Sensor Web application.
  """
  use GasSensorWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {GasSensorWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", GasSensorWeb do
    pipe_through(:browser)

    live("/", DashboardLive, :index)
    live("/sensor", SensorLive, :index)
  end

  # API endpoint for sensor data (optional)
  scope "/api", GasSensorWeb do
    pipe_through(:api)

    get("/readings", SensorController, :index)
    get("/readings/current", SensorController, :current)
  end
end
