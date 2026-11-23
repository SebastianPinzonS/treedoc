defmodule TreedocEquipo.ReplicaTest do
  use ExUnit.Case
  alias TreedocEquipo.{Protocol, Replica}
  test "send y cast convergen, mensajes inválidos no matan el proceso" do
    pid = start_supervised!({Replica, name: :test_replica})
    id = [{1, {1, {:remote, 42}}}]
    send(pid, Protocol.encode({[{id, "a"}], []}))
    assert GenServer.call(pid, :text) == "a"
    GenServer.cast(pid, Protocol.encode({[], [id]}))
    send(pid, {:cpd, 1, :remote, {:estado, [{[], "bad"}], []}})
    assert GenServer.call(pid, :text) == ""
    assert Process.alive?(pid)
    assert :ok == GenServer.call(pid, {:insert, 0, "b"})
    assert GenServer.call(pid, :text) == "b"
  end
end
