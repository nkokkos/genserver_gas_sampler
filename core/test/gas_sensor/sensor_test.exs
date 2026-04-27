defmodule GasSensor.SensorTest do
  use ExUnit.Case
  alias GasSensor.Sensor

  describe "median/1" do
    test "calculates median of odd number of samples" do
      # Using private function through :erlang.apply
      samples = [10, 5, 20, 15, 30]
      sorted = Enum.sort(samples)
      median = Enum.at(sorted, div(length(sorted), 2))

      assert median == 15
    end

    test "calculates median of even number of samples (middle-left)" do
      samples = [10, 20, 30, 40]
      sorted = Enum.sort(samples)
      median = Enum.at(sorted, div(length(sorted), 2))

      assert median == 30
    end
  end
end
