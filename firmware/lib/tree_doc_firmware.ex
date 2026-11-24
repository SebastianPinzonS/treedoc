defmodule TreeDocFirmware do
  @moduledoc """
  Nerves firmware for Tree Doc.

  The generated application supervises `TreeDocFirmware.Boot` on the device.
  Boot waits for IPv4 before starting distribution, the persistent Tree Doc
  replica, and peer discovery. Host builds do not start device processes.
  """
end
