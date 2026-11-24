defmodule TreeDoc.Protocol do
  @moduledoc "Operaciones causales enviadas como cast a Crdt.Replica."
  def decode({:remote, %{from: from, vc: vc, pos: pos} = op}) when is_atom(from) and is_map(vc) do
    valid_clock = Enum.all?(vc, fn {n, s} -> is_atom(n) and is_integer(s) and s >= 0 end)
    seq = Map.get(vc, from, 0)

    if valid_clock and is_integer(seq) and seq > 0 and posid?(pos) and payload?(op),
      do: {:ok, op},
      else: :ignore
  end

  def decode(_), do: :ignore
  defp payload?(%{op: :del}), do: true
  defp payload?(%{op: :ins, ch: ch}), do: is_binary(ch)
  defp payload?(_), do: false
  defp posid?([_ | _] = steps), do: steps?(steps)
  defp posid?(_), do: false
  defp steps?([]), do: true

  defp steps?([{bit, seq, writer} | rest])
       when bit in [0, 1] and is_integer(seq) and seq > 0 and is_atom(writer), do: steps?(rest)

  defp steps?(_), do: false
end
