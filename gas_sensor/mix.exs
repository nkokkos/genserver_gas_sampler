# Run "mix help compile.app" to learn about applications.
# Run "mix help deps" to learn about dependencies.

defmodule GasSensor.MixProject do
  use Mix.Project

  def project do
    [
      app: :gas_sensor,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GasSensor.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [ 
      {:circuits_i2c,  "~> 2.0"},
      {:circuits_gpio, "~> 2.1"},
      {:bmp280, "~> 0.2" },
     
      # use the adc1115 for the time being
      # {:ads1115, "~> 0.1"},

      # add this package https://hex.pm/packages/fostrom
      # {:fostrom, "~> 0.1.0"}
    ]
  end
end
