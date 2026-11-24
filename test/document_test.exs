defmodule TreeDoc.DocumentTest do
  use ExUnit.Case, async: true
  alias TreeDoc.{Document, Causal, Protocol, Store}

  defp op(writer, seq, char, deps \\ %{}) do
    %{op: :ins, pos: [{1, seq, writer}], ch: char, from: writer, vc: Map.put(deps, writer, seq)}
  end

  test "prepare y effect insertan y borran por índices visibles" do
    {:ok, a} = Document.prepare(Document.new(), {:insert, 0, "á"}, {1, :a})
    d = Document.effect(Document.new(), a)
    {:ok, b} = Document.prepare(d, {:insert, 0, "👩‍💻"}, {2, :a})
    d = Document.effect(d, b)
    assert Document.text(d) == "👩‍💻á"
    {:ok, delete} = Document.prepare(d, {:delete, 1}, {3, :a})
    assert Document.text(Document.effect(d, delete)) == "👩‍💻"
    assert {:error, :invalid_index} = Document.prepare(d, {:delete, 2}, {3, :a})
    assert {:error, :invalid_character} = Document.prepare(d, {:insert, 0, "dos"}, {3, :a})
  end

  test "operaciones del mismo autor esperan secuencias previas" do
    {s, []} = Causal.receive_op(Causal.new(), op(:a, 2, "b"))
    assert Document.text(s.doc) == ""
    {s, applied} = Causal.receive_op(s, op(:a, 1, "a"))
    assert length(applied) == 2
    assert s.pending == %{}
    assert Document.text(s.doc) == "ab"
  end

  test "dependencias entre autores se desbloquean transitivamente" do
    {s, []} = Causal.receive_op(Causal.new(), op(:c, 1, "c", %{b: 1, a: 1}))
    {s, []} = Causal.receive_op(s, op(:b, 1, "b", %{a: 1}))
    {s, applied} = Causal.receive_op(s, op(:a, 1, "a"))
    assert Enum.map(applied, & &1.from) == [:a, :b, :c]
    assert Document.text(s.doc) == "abc"
  end

  test "duplicados aplicados y pendientes no crecen" do
    later = op(:a, 2, "b")
    {s, []} = Causal.receive_op(Causal.new(), later)
    {s, []} = Causal.receive_op(s, later)
    assert map_size(s.pending) == 1
    {s, _} = Causal.receive_op(s, op(:a, 1, "a"))
    assert {s, []} == Causal.receive_op(s, later)
  end

  test "concurrencia independiente converge en ambos órdenes" do
    a = op(:a, 1, "a")
    b = op(:b, 1, "b")

    results =
      for ops <- [[a, b], [b, a]] do
        Enum.reduce(ops, Causal.new(), fn op, s -> elem(Causal.receive_op(s, op), 0) end)
      end

    [a, b] = results
    assert a.doc == b.doc
    assert a.vc == b.vc
  end

  test "borrado causal recibido primero espera a su inserción" do
    insert = op(:a, 1, "a")
    delete = %{op: :del, pos: insert.pos, from: :b, vc: %{a: 1, b: 1}}
    {s, []} = Causal.receive_op(Causal.new(), delete)
    {s, [^insert, ^delete]} = Causal.receive_op(s, insert)
    assert Document.text(s.doc) == ""
    assert map_size(s.doc.atoms) == 1
  end

  test "mensajes mal formados y protocolo delta antiguo se rechazan" do
    for invalid <- [
          op(:a, 0, "x"),
          %{op(:a, 1, "x") | vc: %{a: -1}},
          %{op(:a, 1, "x") | pos: []},
          %{op(:a, 1, "x") | pos: [{1, 1, :a} | :bad]},
          %{op(:a, 1, "x") | ch: 123}
        ] do
      assert Protocol.decode({:remote, invalid}) == :ignore
    end

    assert Protocol.decode({:cpd, 1, :a, {:estado, [], []}}) == :ignore
    assert {:ok, _} = Protocol.decode({:remote, op(:a, 1, "x")})
  end

  test "snapshot corrupto se rechaza" do
    path = Path.join(System.tmp_dir!(), "treedoc-corrupt-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)
    File.write!(path, "bad")
    assert Store.load(path) == {:error, :invalid_history}
  end
end
