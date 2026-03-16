# Code Starts here
defmodule SampleSensor do
  @moduledoc """
  GenServer for a Gas Sensor via ADS1115 ADC.
  Samples 7 times evenly spread over 5 seconds.
  Applies median filter and saves result to state.
  """

 # First read the datasheet from TI and undestand the configuration register
 # https://www.ti.com/lit/ds/symlink/ads1115.pdf?ts=1773639841733&ref_url=https%253A%252F%252Fwww.ti.com%252Fproduct%252FADS1115%253Futm_source%253Dgoogle%2526utm_medium%253Dcpc%2526utm_campaign%253Dasc-null-null-GPN_EN-cpc-pf-google-eu_en_cons%2526utm_content%253DADS1115%2526ds_k%253DADS1115+Datasheet%2526DCM%253Dyes%2526gclsrc%253Daw.ds%2526gad_source%253D1%2526gad_campaignid%253D8752110670%2526gclid%253DEAIaIQobChMIp5KkltujkwMVb8tEBx2uNifCEAAYASAAEgJO1_D_BwE#page=24&zoom=auto,-209,731



end
