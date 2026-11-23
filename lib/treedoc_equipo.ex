defmodule TreedocEquipo do
  @moduledoc "API local. insert/2 inserta un grafema y delete/1 borra uno; índices desde cero."
  def insert(index, char), do: GenServer.call(:cpd_doc, {:insert, index, char})
  def delete(index), do: GenServer.call(:cpd_doc, {:delete, index})
  def text, do: GenServer.call(:cpd_doc, :text)
  def state, do: GenServer.call(:cpd_doc, :state)
  def sync, do: send(:cpd_doc, :announce)
end
