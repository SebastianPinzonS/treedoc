defmodule TreeDoc.Store do
  @moduledoc "Snapshot local del historial antes de confirmar o difundir operaciones."
  alias TreeDoc.{Causal, Protocol}
  def load(nil), do: {:ok, Causal.new()}

  def load(path) do
    case File.read(path) do
      {:error, :enoent} -> {:ok, Causal.new()}
      {:ok, binary} -> decode(binary)
      error -> error
    end
  end

  defp decode(binary) do
    # Archivo local de confianza, nunca bytes de la red. Puede contener nombres
    # de nodos que todavía no existen como átomos en esta VM después de reiniciar.
    try do
      {:treedoc_ops, 1, ops} = :erlang.binary_to_term(binary)

      state =
        Enum.reduce(ops, Causal.new(), fn op, s ->
          {:ok, ^op} = Protocol.decode({:remote, op})
          {next, _} = Causal.receive_op(s, op)
          next
        end)

      if map_size(state.pending) == 0, do: {:ok, state}, else: {:error, :incomplete_history}
    rescue
      _ -> {:error, :invalid_history}
    end
  end

  def save(nil, _history), do: :ok

  def save(path, history) do
    temp = path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, fd} <- :file.open(String.to_charlist(temp), [:write, :binary, :raw]) do
      result =
        with :ok <- :file.write(fd, :erlang.term_to_binary({:treedoc_ops, 1, history})),
             :ok <- :file.sync(fd),
             do: :ok

      closed = :file.close(fd)
      with :ok <- result, :ok <- closed, do: File.rename(temp, path)
    end
  end
end
