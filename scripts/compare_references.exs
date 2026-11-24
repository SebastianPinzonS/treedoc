# mix run scripts/compare_references.exs ..
root = List.first(System.argv()) || Path.expand("..")
# Load each reference separately: both declare the same module names.
for team <- ["felipe/treedoc", "diego/treedoc-nerves"] do
  for module <- [Crdt.Treedoc, Crdt.Causal] do
    :code.purge(module)
    :code.delete(module)
  end

  for file <- ["treedoc.ex", "causal.ex"] do
    Code.require_file(Path.join([root, team, "lib", "crdt", file]))
  end

  alias TreeDoc.{Causal, Document, Protocol}
  {:ok, local} = Document.prepare(Document.new(), {:insert, 0, "A"}, {1, :ours})
  local = Map.merge(local, %{from: :ours, vc: %{ours: 1}})
  reference = %{doc: Crdt.Treedoc.new(), vc: %{}, buffer: []}
  {reference, _} = Crdt.Causal.receive_message(reference, local, &Crdt.Treedoc.effect/2)
  {ours, _} = Causal.receive_op(Causal.new(), local)
  {:ok, remote} = Crdt.Treedoc.prepare(reference.doc, {:insert, 1, "B"}, {1, :theirs})
  remote = Map.merge(remote, %{from: :theirs, vc: %{ours: 1, theirs: 1}})
  {:ok, ^remote} = Protocol.decode({:remote, remote})
  {ours, _} = Causal.receive_op(ours, remote)
  {reference, _} = Crdt.Causal.receive_message(reference, remote, &Crdt.Treedoc.effect/2)
  {:ok, delete} = Document.prepare(ours.doc, {:delete, 0}, {2, :ours})
  delete = Map.merge(delete, %{from: :ours, vc: %{ours: 2, theirs: 1}})
  {ours, _} = Causal.receive_op(ours, delete)
  {reference, _} = Crdt.Causal.receive_message(reference, delete, &Crdt.Treedoc.effect/2)
  true = Document.text(ours.doc) == "B"
  true = Document.text(ours.doc) == Crdt.Treedoc.value(reference.doc)
  # Replay in reverse causal order with duplicates into empty replicas.
  {replayed, reference2} =
    Enum.reduce(
      [delete, remote, remote, local, delete],
      {Causal.new(), %{doc: Crdt.Treedoc.new(), vc: %{}, buffer: []}},
      fn op, {a, b} ->
        {a, _} = Causal.receive_op(a, op)
        {b, _} = Crdt.Causal.receive_message(b, op, &Crdt.Treedoc.effect/2)
        {a, b}
      end
    )

  true = replayed.doc == ours.doc
  true = replayed.vc == reference2.vc
  true = Crdt.Treedoc.value(reference2.doc) == "B"
  IO.puts("OK #{team}: inserción bidireccional, borrado, causalidad, duplicados y replay")
end
