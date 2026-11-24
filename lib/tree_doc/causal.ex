defmodule TreeDoc.Causal do
  @moduledoc "Entrega causal, deduplicación y cola por identidad {autor, secuencia}."
  alias TreeDoc.Document
  def new, do: %{doc: Document.new(), vc: %{}, pending: %{}, history: []}
  def id(op), do: {op.from, Map.fetch!(op.vc, op.from)}

  def receive_op(s, op) do
    {writer, seq} = id(op)

    if seq <= Map.get(s.vc, writer, 0) do
      {s, []}
    else
      drain(%{s | pending: Map.put_new(s.pending, id(op), op)}, [])
    end
  end

  defp ready?(s, op) do
    op.vc[op.from] == Map.get(s.vc, op.from, 0) + 1 and
      Enum.all?(op.vc, fn {n, seq} -> n == op.from or seq <= Map.get(s.vc, n, 0) end)
  end

  defp drain(s, applied) do
    case Enum.find(s.pending, fn {_, op} -> ready?(s, op) end) do
      nil ->
        {s, Enum.reverse(applied)}

      {key, op} ->
        next = %{
          s
          | doc: Document.effect(s.doc, op),
            vc: Map.put(s.vc, op.from, op.vc[op.from]),
            pending: Map.delete(s.pending, key),
            history: s.history ++ [op]
        }

        drain(next, [op | applied])
    end
  end
end
