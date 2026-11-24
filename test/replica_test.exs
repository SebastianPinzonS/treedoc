defmodule TreeDoc.ReplicaTest do
  use ExUnit.Case
  alias TreeDoc.Replica

  test "send y cast, errores locales y mensajes inválidos" do
    pid = start_supervised!({Replica, name: :test_replica, path: nil, me: :local})
    op = %{op: :ins, pos: [{1, 1, :remote}], ch: "a", from: :remote, vc: %{remote: 1}}
    send(pid, {:remote, op})
    GenServer.cast(pid, {:remote, op})
    send(pid, {:remote, %{}})
    assert GenServer.call(pid, :text) == "a"
    before = GenServer.call(pid, :state)
    assert {:error, :invalid_index} = GenServer.call(pid, {:insert, 99, "b"})
    assert GenServer.call(pid, :state) == before
    assert :ok == GenServer.call(pid, {:insert, 1, "b"})
    assert GenServer.call(pid, :text) == "ab"
    assert GenServer.call(pid, :state).vc == %{local: 1, remote: 1}
  end

  test "reinicio restaura documento y contador sin reutilizar secuencias" do
    path =
      Path.join(System.tmp_dir!(), "treedoc-restart-#{System.unique_integer([:positive])}.etf")

    on_exit(fn -> File.rm(path) end)
    {:ok, first} = Replica.start_link(name: :restart_test, path: path, me: :stable)
    assert :ok == GenServer.call(first, {:insert, 0, "a"})
    GenServer.stop(first)
    {:ok, second} = Replica.start_link(name: :restart_test, path: path, me: :stable)

    try do
      assert GenServer.call(second, :text) == "a"
      assert :ok == GenServer.call(second, {:insert, 1, "b"})
      assert GenServer.call(second, :state).vc == %{stable: 2}
      assert GenServer.call(second, :text) == "ab"
    after
      GenServer.stop(second)
    end
  end

  test "fallo de escritura no confirma ni cambia estado local" do
    dir = Path.join(System.tmp_dir!(), "treedoc-io-#{System.unique_integer([:positive])}")
    path = Path.join(dir, "history.etf")
    on_exit(fn -> File.rm_rf(dir) end)
    pid = start_supervised!({Replica, name: :io_test, path: path, me: :a})
    File.write!(dir, "blocks mkdir")
    assert {:error, {:storage, _}} = GenServer.call(pid, {:insert, 0, "a"})
    assert GenServer.call(pid, :text) == ""
    assert GenServer.call(pid, :state).vc == %{}
  end
end
