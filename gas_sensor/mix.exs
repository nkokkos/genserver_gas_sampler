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
      {:circuits_i2c, "~> 2.0"}
    ]
  end
end
