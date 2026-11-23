# Ejecutar desde la raíz: mix run scripts/compare_references.exs /ruta/CRDT
root = List.first(System.argv()) || Path.expand("..")
for path <- ["carla/distribution-project-/documento/lib/cpd_doc/protocolo.ex",
             "carla/distribution-project-/documento/lib/cpd_doc/treedoc.ex",
             "andres/treedoc-state-nerves/lib/doc/protocol.ex",
             "andres/treedoc-state-nerves/lib/doc/treedoc.ex"] do
  Code.require_file(Path.join(root, path))
end
alias TreedocEquipo.{Document, Protocol}
check = fn true, label -> IO.puts("OK: " <> label)
           false, label -> raise("Fallo: " <> label) end
id = [{1, {1, {:a, 1}}}]
{:ok, ours, delta} = Document.insert(Document.new(), 0, "a", {:ours, 10})
{:ok, cd} = CpdDoc.Protocolo.leer(Protocol.encode(delta))
carla = CpdDoc.Treedoc.merge(CpdDoc.Treedoc.nuevo(), cd)
{:ok, _, atoms, tombs} = Doc.Protocol.parse(Protocol.encode(delta))
{andres, _, _} = Doc.Treedoc.merge(Doc.Treedoc.new(), atoms, tombs)
check.(Document.text(ours) == CpdDoc.Treedoc.texto(carla), "nuestro delta llega a Carla")
check.(Document.text(ours) == Doc.Treedoc.value(andres), "nuestro delta llega a Andrés")
{carla, dc} = CpdDoc.Treedoc.insertar(carla, 1, "c", {:carla, 20})
{:ok, incoming} = Protocol.decode(CpdDoc.Protocolo.mensaje(dc))
ours = Document.merge(ours, incoming)
check.(Document.text(ours) == CpdDoc.Treedoc.texto(carla), "delta de Carla llega a nosotros")
{:ok, op} = Doc.Treedoc.prepare(andres, {:insert, 1, "b"}, {2, {:andres, 30}})
andres = Doc.Treedoc.effect(andres, op)
{:ok, incoming} = Protocol.decode(Doc.Protocol.msg(elem(Doc.Treedoc.delta(op), 0), []))
ours = Document.merge(ours, incoming)
{atoms, tombs} = Document.state(ours)
{andres, _, _} = Doc.Treedoc.merge(andres, atoms, tombs)
check.(Document.text(ours) == Doc.Treedoc.value(andres), "delta de Andrés y estado completo convergen")
conflict = {[{id, "x"}, {id, "y"}], []}
{:ok, cd} = CpdDoc.Protocolo.leer(Protocol.encode(conflict))
{ad, _, _} = Doc.Treedoc.merge(Doc.Treedoc.new(), elem(conflict, 0), [])
check.(CpdDoc.Treedoc.texto(cd) == "y" and Doc.Treedoc.value(ad) == "x", "reproducida incompatibilidad max/min")
msg = Protocol.encode({[{id, "dos"}], []})
check.(match?({:ok, _}, CpdDoc.Protocolo.leer(msg)) and Doc.Protocol.parse(msg) == :ignore,
  "reproducida incompatibilidad en validación de caracteres")
IO.puts("Comparación de módulos reales completada; no sustituye una prueba de red entre Pis.")
