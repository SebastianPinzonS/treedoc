defmodule TreeDoc.Replica do
  use GenServer
  alias TreeDoc.{Causal, Document, Protocol, Store}

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, Crdt.Replica))

  @impl true
  def init(opts) do
    me = Keyword.get(opts, :me, node())

    default_path =
      Path.join(
        System.get_env("TREEDOC_DATA_DIR", "data"),
        Base.url_encode64(Atom.to_string(me), padding: false) <> ".etf"
      )

    path = Keyword.get(opts, :path, default_path)

    with {:ok, core} <- Store.load(path) do
      :net_kernel.monitor_nodes(true)
      interval = Keyword.get(opts, :interval, 30_000)
      Process.send_after(self(), :sync, interval)
      send(self(), :startup)
      {:ok, %{core: core, me: me, path: path, interval: interval}}
    else
      {:error, reason} -> {:stop, {:history_load_failed, reason}}
    end
  end

  @impl true
  def handle_call({:insert, index, char}, _from, s), do: edit(s, {:insert, index, char})
  def handle_call({:delete, index}, _from, s), do: edit(s, {:delete, index})
  def handle_call(:text, _, s), do: {:reply, Document.text(s.core.doc), s}
  def handle_call(:state, _, s), do: {:reply, s.core, s}
  def handle_call(_, _, s), do: {:reply, {:error, :unknown_call}, s}

  defp edit(s, request) do
    seq = Map.get(s.core.vc, s.me, 0) + 1

    case Document.prepare(s.core.doc, request, {seq, s.me}) do
      {:error, _} = error ->
        {:reply, error, s}

      {:ok, operation} ->
        op = Map.merge(operation, %{from: s.me, vc: Map.put(s.core.vc, s.me, seq)})
        {core, applied} = Causal.receive_op(s.core, op)

        case persist(s, core, applied) do
          {:ok, next} -> {:reply, :ok, next}
          {:error, reason} -> {:reply, {:error, {:storage, reason}}, s}
        end
    end
  end

  @impl true
  def handle_cast({:hello, n}, s) when is_atom(n), do: replay(s)
  def handle_cast(message, s), do: receive_message(message, s)
  @impl true
  def handle_info(:startup, s) do
    broadcast({:hello, s.me})
    replay(s)
  end

  def handle_info(:sync, s) do
    Process.send_after(self(), :sync, s.interval)
    replay(s)
  end

  def handle_info(:announce, s), do: replay(s)

  def handle_info({:nodeup, _}, s) do
    broadcast({:hello, s.me})
    replay(s)
  end

  def handle_info(message, s), do: receive_message(message, s)

  defp receive_message(message, s) do
    case Protocol.decode(message) do
      :ignore ->
        {:noreply, s}

      {:ok, op} ->
        {core, applied} = Causal.receive_op(s.core, op)

        case persist(s, core, applied) do
          {:ok, next} -> {:noreply, next}
          {:error, reason} -> {:stop, {:storage, reason}, s}
        end
    end
  end

  defp persist(s, core, []), do: {:ok, %{s | core: core}}

  defp persist(s, core, applied) do
    with :ok <- Store.save(s.path, core.history) do
      Enum.each(applied, &broadcast({:remote, &1}))
      {:ok, %{s | core: core}}
    end
  end

  defp replay(s) do
    Enum.each(s.core.history, &broadcast({:remote, &1}))
    {:noreply, s}
  end

  defp broadcast(message) do
    for peer <- Node.list(), do: GenServer.cast({Crdt.Replica, peer}, message)
    :ok
  end
end
