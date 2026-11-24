defmodule TreeDoc.Document do
  @moduledoc "Treedoc puro con posiciones compatibles con Felipe y Diego."
  def new, do: %{atoms: %{}, tombstones: MapSet.new()}
  def less?([], []), do: false
  def less?([], [{bit, _, _} | _]), do: bit == 1
  def less?([{bit, _, _} | _], []), do: bit == 0
  def less?([x | a], [x | b]), do: less?(a, b)
  def less?([x | _], [y | _]), do: x < y

  def visible(doc) do
    doc.atoms
    |> Enum.reject(fn {id, _} -> MapSet.member?(doc.tombstones, id) end)
    |> Enum.sort(fn {a, _}, {b, _} -> less?(a, b) end)
  end

  def text(doc), do: Enum.map_join(visible(doc), &elem(&1, 1))

  def prepare(doc, {:insert, index, char}, {seq, writer}) do
    items = visible(doc)

    cond do
      not is_integer(index) or index < 0 or index > length(items) ->
        {:error, :invalid_index}

      not is_binary(char) ->
        {:error, :invalid_character}

      not String.valid?(char) or length(String.graphemes(char)) != 1 ->
        {:error, :invalid_character}

      true ->
        left = if index == 0, do: [], else: elem(Enum.at(items, index - 1), 0)

        right =
          case Enum.at(items, index) do
            nil -> nil
            {id, _} -> id
          end

        pos =
          if right != nil and List.starts_with?(right, left),
            do: right ++ [{0, seq, writer}],
            else: left ++ [{1, seq, writer}]

        {:ok, %{op: :ins, pos: pos, ch: char}}
    end
  end

  def prepare(doc, {:delete, index}, _dot) do
    items = visible(doc)

    if is_integer(index) and index >= 0 and index < length(items),
      do: {:ok, %{op: :del, pos: elem(Enum.at(items, index), 0)}},
      else: {:error, :invalid_index}
  end

  def effect(doc, %{op: :ins, pos: id, ch: char}),
    do: %{doc | atoms: Map.put(doc.atoms, id, char)}

  def effect(doc, %{op: :del, pos: id}), do: %{doc | tombstones: MapSet.put(doc.tombstones, id)}
end
