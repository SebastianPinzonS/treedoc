defmodule TreeDocFirmwareTest do
  use ExUnit.Case, async: false

  test "host application starts no device workers or document replica" do
    previous_replica = Process.whereis(Crdt.Replica)
    {:ok, supervisor} = TreeDocFirmware.Application.start(:normal, [])

    try do
      assert Supervisor.which_children(supervisor) == []
      assert Process.whereis(TreeDocFirmware.Boot) == nil
      assert Process.whereis(Crdt.Replica) == previous_replica
    after
      Supervisor.stop(supervisor)
    end
  end
end
