defmodule TreeDoc.ReplicaTest do
  use ExUnit.Case
  alias TreeDoc.Replica

  test "inserts text at visible indices and replays each grapheme" do
    pid = start_supervised!({Replica, name: :text_test, path: nil, me: :local})
    assert :ok == GenServer.call(pid, {:insert, 0, "ac"})
    assert :ok == GenServer.call(pid, {:insert, 1, "👩‍💻é"})
    assert :ok == GenServer.call(pid, {:insert, 0, "Hi "})
    assert :ok == GenServer.call(pid, {:insert, 7, "!\n"})
    assert GenServer.call(pid, :text) == "Hi a👩‍💻éc!\n"
    assert :ok == GenServer.call(pid, {:delete, 4})
    assert GenServer.call(pid, :text) == "Hi aéc!\n"
    state = GenServer.call(pid, :state)
    assert state.vc == %{local: 10}

    replay =
      Enum.reduce(Enum.reverse(state.history), TreeDoc.Causal.new(), fn op, core ->
        assert {:ok, ^op} = TreeDoc.Protocol.decode({:remote, op})
        elem(TreeDoc.Causal.receive_op(core, op), 0)
      end)

    assert replay.doc == state.doc
    assert replay.pending == %{}

    for {index, text, reason} <- [
          {99, "abc", :invalid_index},
          {-1, "abc", :invalid_index},
          {"0", "abc", :invalid_index},
          {0, "", :invalid_character},
          {0, <<255>>, :invalid_character},
          {0, 123, :invalid_character}
        ] do
      assert {:error, ^reason} = GenServer.call(pid, {:insert, index, text})
      assert GenServer.call(pid, :state) == state
    end
  end

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
    assert :ok == GenServer.call(first, {:insert, 0, "abc"})
    GenServer.stop(first)
    {:ok, second} = Replica.start_link(name: :restart_test, path: path, me: :stable)

    try do
      assert GenServer.call(second, :text) == "abc"
      assert :ok == GenServer.call(second, {:insert, 3, "de"})
      assert GenServer.call(second, :state).vc == %{stable: 5}
      assert GenServer.call(second, :text) == "abcde"
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
    assert {:error, {:storage, _}} = GenServer.call(pid, {:insert, 0, "abc"})
    assert GenServer.call(pid, :text) == ""
    assert GenServer.call(pid, :state).vc == %{}
  end
end
