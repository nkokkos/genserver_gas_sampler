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

    #live("/", DashboardLive, :index)
    #live("/sensor", SensorLive, :index)
  
    # root to 
    live "/", SensorDetailLive, :index

    # set up the new graph
    live("/sensor/detail", SensorDetailLive, :index)

    # set up the configuration page for vsensor offset
    live("/sensor/offset", VsensoroffsetLive, :index)    
    live("/sensor/volts", SensorVoltsLive, :index)
    live("/sensor/history", SensorHistoryLive, :index)
  end

  # API endpoint for sensor data (optional)
  scope "/api", GasSensorWeb do
    pipe_through(:api)

    get("/readings", SensorController, :index)
    get("/readings/current", SensorController, :current)
  end
end
