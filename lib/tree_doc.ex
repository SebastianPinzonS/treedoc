defmodule TreeDoc do
  @moduledoc "API local. insert/2 inserta un grafema y delete/1 borra uno; índices desde cero."
  def insert(index, char), do: GenServer.call(Crdt.Replica, {:insert, index, char})
  def delete(index), do: GenServer.call(Crdt.Replica, {:delete, index})
  def text, do: GenServer.call(Crdt.Replica, :text)
  def state, do: GenServer.call(Crdt.Replica, :state)
  def sync, do: send(Crdt.Replica, :announce)
end
