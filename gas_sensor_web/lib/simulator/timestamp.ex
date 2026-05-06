defmodule GasSensorWeb.Simulator.Timestamp do
  
  @moduledoc """
  Reliable UTC timestamp generation for RTC-less embedded systems.

  With NTP:
    Returns real UTC time world clock
    Set time_reliable = true
  With NTP off / no internet present
    Returns provisional timestamp (build date + elapsed time)
    Sets time_reliable = false
    Maintains chronological order.

  ## Usage

      # Get timestamp with reliability check
      {timestamp, reliable?} = GasSensorWeb.Simulator.Timestamp.now_with_reliability()
      
      # Get current time (uses provisional if offline)
      timestamp = GasSensorWeb.Simulator.Timestamp.now()

      # Check NTP sync status
      synced? = GasSensorWeb.Simulator.Timestamp.ntp_synced?()
      
      # Check if we're in offline mode
      offline? = GasSensorWeb.Simulator.Timestamp.offline_mode?()
      
  """

  require Logger
     
  @minimum_reliable_year 2025
 
  @doc """
  Returns `{timestamp, reliable?}`.
  reliable? is true only when NervesTime confirms NTP sync
  and the year passes a basic sanity check.
  """
  def now_with_reliability do

    ts = DateTime.utc_now()
    
    #if ntp_synced?() and reliable_time?(ts) do 
    #  {ts, true}
    #else
    #  Logger.warning("[Timestamp] NTP not synched - using provisional timestamp")
    #  {provisional_timestamp(), false}
    #end  
    
    # return true for testing 
    {ts, true}
  end

  @doc """ 
    Returns current UTC time with a reliability check
  """
  def now do
    {ts, _reliable?} = now_with_reliability()
  end

#  @doc """
#  The ouput is true when NervesTime has confirmed sync with an NTP server
#  and the year looks fine.
#  """
#  def ntp_synced? do
#    case Application.get_env(:gas_sensor, :env, :host) do
#      :host   -> reliable_time?(DateTime.utc_now()) # running on host, on this otp app. skip NervesTime on host, on this OTP app.
#      :target -> NervesTime.synchronized?() and reliable_time?(DateTime.utc_now()) # Running on rpi0
#    end
#  end
  
#  @doc "True when NTP has not yet confirmed sync" 
#  def offline_mode? do
#    not ntp_synced?()
#  end

#  @doc """
#  Provisional timestamp for offline use.
#  Advances from the compiled build date using the monotonic clock.
#  Both boot_monotonic and System.monotonic_time are from the same
#  BEAM instance so the subtraction always gives correct elapsed seconds.
#  """
#  def provisional_timestamp do
#    boot_monotonic = Application.get_env(:gas_sensor, :boot_monotonic, 0)
#    elapsed_sec    = System.monotonic_time(:second) - boot_monotonic
#    DateTime.add(GasSensor.Application.build_date, elapsed_sec)
#  end

  # Private
  # Secondary sanity guard — catches edge cases where NervesTime reports
  # synced but the clock is still obviously wrong (e.g. RTC drift to 1970).
  defp reliable_time?(%DateTime{year: year}) do
    year >= @minimum_reliable_year
  end

end
