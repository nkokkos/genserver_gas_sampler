# Run "mix help compile.app" to learn about applications.
# Run "mix help deps" to learn about dependencies.

defmodule Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :gas_sensor,
      version: "0.1.2",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {GasSensor.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end
  
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [ 
      {:circuits_i2c,  "~> 2.0"},
      {:circuits_gpio, "~> 2.1"},

      # Use Bosch barometric pressure sensors in Elixir 
      # use this librar maintained by Frank Hunleth:
      # https://github.com/elixir-sensors/bmp280
      {:bmp280, "~> 0.2" }
      

      # add this package https://hex.pm/packages/fostrom
      # {:fostrom, "~> 0.1.0"}
    ]
  end
end
