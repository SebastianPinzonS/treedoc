defmodule TreedocEquipo.Document do
  @moduledoc "Estado puro de Treedoc. Los índices locales cuentan grafemas visibles desde cero."
  def new, do: %{atoms: %{}, tombstones: MapSet.new(), counter: 0}

  def less?([], []), do: false
  def less?([], [{bit, _} | _]), do: bit == 1
  def less?([{bit, _} | _], []), do: bit == 0
  def less?([x | a], [x | b]), do: less?(a, b)
  def less?([x | _], [y | _]), do: x < y

  def merge(doc, {atoms, tombstones}) do
    merged = Enum.reduce(atoms, doc.atoms, fn {id, char}, acc ->
      Map.update(acc, id, char, &max(&1, char))
    end)
    %{doc | atoms: merged, tombstones: MapSet.union(doc.tombstones, MapSet.new(tombstones))}
  end

  def state(doc), do: {Map.to_list(doc.atoms), MapSet.to_list(doc.tombstones)}
  def ordered(doc), do: Enum.sort(Map.to_list(doc.atoms), fn {a, _}, {b, _} -> less?(a, b) end)
  def visible(doc), do: Enum.reject(ordered(doc), fn {id, _} -> MapSet.member?(doc.tombstones, id) end)
  def text(doc), do: Enum.map_join(visible(doc), fn {_, ch} -> ch end)

  def insert(doc, index, char, site) do
    items = visible(doc)
    cond do
      not is_integer(index) or index < 0 or index > length(items) -> {:error, :invalid_index}
      not is_binary(char) -> {:error, :invalid_character}
      not String.valid?(char) or length(String.graphemes(char)) != 1 -> {:error, :invalid_character}
      true ->
        left = if index == 0, do: :start, else: elem(Enum.at(items, index - 1), 0)
        # Include deleted identifiers, even tombstones received before their atoms.
        ids = Map.keys(doc.atoms) ++ MapSet.to_list(doc.tombstones)
        right = ids |> Enum.uniq() |> Enum.sort(&less?/2)
          |> Enum.find(:end, fn id -> left == :start or less?(left, id) end)
        counter = doc.counter + 1
        id = allocate(left, right, {counter, site})
        delta = {[{id, char}], []}
        {:ok, %{merge(doc, delta) | counter: counter}, delta}
    end
  end

  def delete(doc, index) do
    items = visible(doc)
    if is_integer(index) and index >= 0 and index < length(items) do
      {id, _} = Enum.at(items, index)
      delta = {[], [id]}
      {:ok, merge(doc, delta), delta}
    else
      {:error, :invalid_index}
    end
  end

  defp allocate(:start, :end, dis), do: [{1, dis}]
  defp allocate(:start, right, dis), do: right ++ [{0, dis}]
  defp allocate(left, :end, dis), do: left ++ [{1, dis}]
  defp allocate(left, right, dis) do
    if List.starts_with?(right, left), do: right ++ [{0, dis}], else: left ++ [{1, dis}]
  end
end
