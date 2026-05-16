# My thoughts: there should be a way to define a default value 
# for the zero CO calibration value which is the
# voltage produced when the gas sensor is in clean air.
# I call that value volt_zero.
# The idea is that you take that value and you insert
# it into the sensor genserver to start counting ppm
# from zero. It get reads everytime the reading agent starts

defmodule GasSensor.ConfigManager do 

  require Logger
  
  # load the load file based on configuration.
  @config_file Application.get_env(:gas_sensor, :config)
  @default_offset 1.0
  
  def init() do
    case File.read(@config_file) do
     {:ok, content} -> 
       content 
       |> Jason.decode!()
       |> Map.get("vsensor_offset", @default_offset)

     {:error, :enoent} ->
       File.mkdir_p!(Path.dirname(@config_file))
       create_vsensor_offset_file(@default_offset)
       @default_offset
    end
  end

  def create_vsensor_offset_file(value) do 
    # build the config using a map and save it to file
    data = %{"vsensor_offset" => value}
    json_content = Jason.encode!(data, pretty: true)
    # this should replace the file:
    File.write!(@config_file, json_content)
  end
  
  def save_vsensor_offset(value) do 
    File.read!(@config_file)
    |> Jason.decode!()
    |> Map.put("vsensor_offset", value)
    |> then(&File.write!(@config_file, Jason.encode!(&1, pretty: true)))
  end
    
  def get_vsensor_offset do
    case File.read(@config_file) do
      {:ok, content} -> 
        content  
        |> Jason.decode!() 
        |> Map.get("vsensor_offset", 0.0) # Returns the value, or 0.0 if the key is missing

      {:error, :enoent} ->
        # Return the default value directly if the file doesn't exist
        @default_offset
    end
  end

end

 
