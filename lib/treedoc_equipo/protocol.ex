defmodule TreedocEquipo.Protocol do
  @moduledoc "Contrato CPD v1 del borrador del 22 de noviembre. Validación completa antes de merge."
  def encode({atoms, tombstones}, origin \\ node()), do: {:cpd, 1, origin, {:estado, atoms, tombstones}}

  def decode({:cpd, 1, origin, {:estado, atoms, tombstones}}) when is_atom(origin) do
    if every?(atoms, &entry?/1) and every?(tombstones, &posid?/1),
      do: {:ok, {atoms, tombstones}}, else: :ignore
  end
  def decode(_), do: :ignore

  defp entry?({id, char}), do: is_binary(char) and posid?(id)
  defp entry?(_), do: false
  defp posid?([_ | _] = id), do: every?(id, &step?/1)
  defp posid?(_), do: false
  defp step?({bit, {counter, {writer, incarnation}}})
       when bit in [0, 1] and is_integer(counter) and is_atom(writer) and is_integer(incarnation), do: true
  defp step?(_), do: false
  defp every?([], _fun), do: true
  defp every?([x | rest], fun), do: fun.(x) and every?(rest, fun)
  defp every?(_, _fun), do: false
end
