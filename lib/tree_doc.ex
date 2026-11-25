defmodule TreeDoc do
  @moduledoc "API local. insert/2 inserta texto y delete/1 borra un grafema; índices desde cero."
  def insert(index, text), do: GenServer.call(Crdt.Replica, {:insert, index, text})
  def delete(index), do: GenServer.call(Crdt.Replica, {:delete, index})
  @doc "Atomically delete PosIDs and insert text after an existing PosID ([] means start)."
  def edit(edit), do: GenServer.call(Crdt.Replica, {:edit, edit})
  def text, do: GenServer.call(Crdt.Replica, :text)
  def state, do: GenServer.call(Crdt.Replica, :state)
  def sync, do: send(Crdt.Replica, :announce)
end
