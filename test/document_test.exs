defmodule TreedocEquipo.DocumentTest do
  use ExUnit.Case, async: true
  alias TreedocEquipo.{Document, Protocol}
  defp id(n), do: [{1, {n, {:a, 1}}}]
  defp v1 do
    p = id(1)
    [{p, "c"}, {p ++ [{0, {2, {:a, 1}}}], "b"},
     {p ++ [{1, {3, {:a, 1}}}], "d"},
     {p ++ [{0, {2, {:a, 1}}}, {0, {4, {:a, 1}}}], "a"}]
  end
  test "V1 y V3: orden infijo y borrado" do
    doc = Document.merge(Document.new(), {v1(), []})
    assert Document.text(doc) == "abcd"
    assert Document.text(Document.merge(doc, {[], [id(1) ++ [{0, {2, {:a, 1}}}]]})) == "acd"
  end
  test "V2: contador antes que nodo y subárbol contiguo" do
    atoms = [{id(2), "Z"}, {[{1, {1, {:b, 1}}}], "Y"},
      {id(1) ++ [{1, {5, {:a, 1}}}], "x"}, {id(1), "X"}]
    assert Document.text(Document.merge(Document.new(), {atoms, []})) == "XxYZ"
  end
  test "V4: borrar antes de insertar" do
    doc = Document.merge(Document.new(), {[], [id(9)]})
    assert Document.text(Document.merge(doc, {[{id(9), "q"}], []})) == ""
  end
  test "V5: conflicto determinista en ambos órdenes y entre mensajes" do
    for chars <- [["x", "y"], ["y", "x"]] do
      doc = Enum.reduce(chars, Document.new(), fn ch, d -> Document.merge(d, {[{id(1), ch}], []}) end)
      assert Document.text(doc) == "y"
      assert Document.text(Document.merge(Document.new(), {Enum.map(chars, &{id(1), &1}), []})) == "y"
    end
  end
  test "merge conmutativo, asociativo e idempotente" do
    a = Document.merge(Document.new(), {[{id(1), "a"}], []})
    b = Document.merge(Document.new(), {[{id(1), "z"}, {id(2), "b"}], []})
    c = Document.merge(Document.new(), {[], [id(2)]})
    join = fn x, y -> Document.merge(x, Document.state(y)) end
    assert join.(a, b) == join.(b, a)
    assert join.(join.(a, b), c) == join.(a, join.(b, c))
    assert join.(a, a) == a
  end
  test "ediciones concurrentes, duplicados y orden arbitrario" do
    {:ok, a, da} = Document.insert(Document.new(), 0, "a", {:a, 1})
    {:ok, b, db} = Document.insert(Document.new(), 0, "b", {:b, 1})
    assert Document.text(Document.merge(a, db)) == Document.text(Document.merge(b, da))
    assert Document.merge(Document.merge(a, db), db) == Document.merge(a, db)
  end
  test "índices visibles, Unicode y tombstones" do
    {:ok, a, _} = Document.insert(Document.new(), 0, "👩‍💻", {:a, 1})
    {:ok, b, _} = Document.insert(a, 1, "b", {:a, 1})
    {:ok, c, _} = Document.delete(b, 0)
    {:ok, d, _} = Document.insert(c, 0, "á", {:a, 1})
    assert Document.text(d) == "áb"
    assert {:error, :invalid_index} = Document.delete(d, 2)
    assert {:error, :invalid_character} = Document.insert(d, 0, "dos", {:a, 1})
    assert map_size(d.atoms) == 3
  end
  test "validación atómica, listas impropias y versiones" do
    good = {id(1), "a"}
    for atoms <- [[good, {[], "b"}], [good | :bad], [{[{2, {1, {:a, 1}}}], "x"}]] do
      assert :ignore == Protocol.decode(Protocol.encode({atoms, []}))
    end
    assert :ignore == Protocol.decode({:cpd, 2, :a, {:estado, [], []}})
    assert :ignore == Protocol.decode(Protocol.encode({[], [id(1) | :bad]}))
    assert :ignore == Protocol.decode(Protocol.encode({[], []}, "not-an-atom"))
  end
  test "recepción admite cualquier binario; emisión local exige un grafema" do
    for binary <- ["", "dos", <<255>>, "👩‍💻"] do
      delta = {[{id(1), binary}], []}
      assert {:ok, ^delta} = Protocol.decode(Protocol.encode(delta))
    end
  end
  test "ediciones secuenciales conservan la posición solicitada" do
    Enum.reduce(1..100, {Document.new(), []}, fn n, {doc, expected} ->
      index = rem(n * 7, length(expected) + 1)
      char = <<?a + rem(n, 26)>>
      {:ok, next, _} = Document.insert(doc, index, char, {:a, 1})
      expected = List.insert_at(expected, index, char)
      assert Document.text(next) == Enum.join(expected)
      {next, expected}
    end)
  end
end
