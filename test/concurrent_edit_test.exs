defmodule TreeDoc.ConcurrentEditTest do
  use ExUnit.Case
  alias TreeDoc.{Document, Protocol, Replica}

  setup do
    a = start_supervised!({Replica, name: :client_a, me: :alice, path: nil}, id: :a)
    b = start_supervised!({Replica, name: :client_b, me: :bob, path: nil}, id: :b)
    %{a: a, b: b}
  end

  defp state(pid), do: GenServer.call(pid, :state)
  defp text(pid), do: GenServer.call(pid, :text)

  defp edit(pid, ids, anchor, text),
    do: GenServer.call(pid, {:edit, %{del: ids, anchor: anchor, ins: text}})

  # Both requests finish before either replica receives the other's operations.
  # This guarantees causal concurrency independently of scheduler timing.
  defp concurrently(left, right) do
    tasks = Enum.map([left, right], &Task.async/1)
    assert Enum.map(tasks, &Task.await/1) == [:ok, :ok]
  end

  defp deliver(pid, ops) do
    for op <- ops do
      assert {:ok, ^op} = Protocol.decode({:remote, op})
      GenServer.cast(pid, {:remote, op})
    end

    state(pid)
  end

  defp converge(a, b) do
    ah = state(a).history
    bh = state(b).history
    # Reordering, duplicates, and complete history replay use the real receiver.
    sa = deliver(a, Enum.reverse(bh) ++ bh)
    sb = deliver(b, Enum.reverse(ah) ++ ah)
    assert sa.doc == sb.doc
    assert sa.vc == sb.vc
    assert sa.pending == %{}
    assert sb.pending == %{}
    assert MapSet.new(sa.history) == MapSet.new(sb.history)
    assert length(sa.history) == MapSet.size(MapSet.new(sa.history))
    assert length(sb.history) == length(sa.history)
    text(a)
  end

  defp seed(a, b, content) do
    assert :ok == GenServer.call(a, {:insert, 0, content})
    deliver(b, state(a).history)
    Enum.map(Document.visible(state(a).doc), &elem(&1, 0))
  end

  test "two PosID clients insert at the same position", %{a: a, b: b} do
    [anchor, _] = seed(a, b, "[]")

    concurrently(
      fn -> edit(a, [], anchor, "ABC") end,
      fn -> edit(b, [], anchor, "xyz") end
    )

    assert text(a) == "[ABC]"
    assert text(b) == "[xyz]"
    assert converge(a, b) in ["[ABCxyz]", "[xyzABC]"]
  end

  test "overlapping replacements preserve both insertions and delete once", %{a: a, b: b} do
    [left, middle, _] = seed(a, b, "abc")

    concurrently(
      fn -> edit(a, [middle], left, "X") end,
      fn -> edit(b, [middle], left, "Y") end
    )

    assert converge(a, b) in ["aXYc", "aYXc"]
    assert MapSet.size(state(a).doc.tombstones) == 1
  end

  test "a stale browser anchor still works after a console deletion", %{a: a, b: b} do
    [_, anchor, _] = seed(a, b, "abc")
    assert :ok == GenServer.call(b, {:delete, 1})
    deliver(a, state(b).history)
    assert :ok == edit(a, [], anchor, "👩‍💻é")
    assert converge(a, b) == "a👩‍💻éc"
  end

  test "PosID client and existing index client can edit concurrently", %{a: a, b: b} do
    [left, _, _] = seed(a, b, "abc")

    concurrently(
      fn -> edit(a, [], left, "WEB") end,
      fn -> GenServer.call(b, {:insert, 1, "IEX"}) end
    )

    assert converge(a, b) in ["aWEBIEXbc", "aIEXWEBbc"]
  end

  test "100 reproducible rounds of disconnected edits converge", %{a: a, b: b} do
    seed(a, b, "start")
    :rand.seed(:exsss, {17, 29, 43})

    for round <- 1..100 do
      before = state(a)

      requests =
        for {pid, label} <- [{a, "A"}, {b, "B"}] do
          atoms = Document.visible(before.doc)
          index = :rand.uniform(length(atoms) + 1) - 1
          anchor = if index == 0, do: [], else: elem(Enum.at(atoms, index - 1), 0)
          ids = atoms |> Enum.slice(index, :rand.uniform(3) - 1) |> Enum.map(&elem(&1, 0))
          {pid, ids, anchor, "#{label}#{round}🧪"}
        end

      [{pa, da, aa, ta}, {pb, db, ab, tb}] = requests
      concurrently(fn -> edit(pa, da, aa, ta) end, fn -> edit(pb, db, ab, tb) end)
      result = converge(a, b)
      assert result =~ ta
      assert result =~ tb
    end
  end

  test "an unblocked remote op cannot become the anchor for the rest of a paste", %{a: a} do
    remote = %{
      op: :ins,
      pos: [{1, 1, :z_remote}],
      ch: "X",
      from: :z_remote,
      vc: %{alice: 1, z_remote: 1}
    }

    assert map_size(deliver(a, [remote]).pending) == 1
    assert :ok == edit(a, [], [], "ab")
    assert text(a) == "abX"
    assert state(a).pending == %{}
  end

  test "invalid replacement leaves both document and history unchanged", %{a: a, b: b} do
    [id] = seed(a, b, "a")
    before = state(a)
    assert {:error, :invalid_edit} == edit(a, [id], [{1, 999, :alice}], "x")
    assert state(a) == before
    assert converge(a, b) == "a"
  end

  test "a merged edit survives restart and can sync subsequent changes", %{a: a, b: b} do
    [anchor] = seed(a, b, "a")

    concurrently(
      fn -> edit(a, [], anchor, "one") end,
      fn -> edit(b, [], anchor, "two") end
    )

    merged = converge(a, b)

    path =
      Path.join(System.tmp_dir!(), "treedoc-concurrent-#{System.unique_integer([:positive])}.etf")

    on_exit(fn -> File.rm(path) end)
    opts = [name: :durable_client, me: :durable, path: path]
    p = start_supervised!({Replica, opts}, id: :durable)
    deliver(p, Enum.reverse(state(a).history))
    assert :ok == edit(p, [], anchor, "saved")
    expected = text(p)
    refute expected == merged
    stop_supervised!(:durable)
    restarted = start_supervised!({Replica, opts}, id: :durable)
    assert text(restarted) == expected
    assert :ok == edit(restarted, [], anchor, "again")
    assert converge(restarted, a) =~ "again"
    assert converge(a, b) == text(restarted)
  end
end
