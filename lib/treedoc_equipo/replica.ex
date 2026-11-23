defmodule TreedocEquipo.Replica do
  use GenServer
  alias TreedocEquipo.{Document, Protocol}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, :cpd_doc))

  @impl true
  def init(opts) do
    :net_kernel.monitor_nodes(true)
    interval = Keyword.get(opts, :interval, 30_000)
    incarnation = :crypto.strong_rand_bytes(16) |> :binary.decode_unsigned()
    Process.send_after(self(), :sync, interval)
    send(self(), :announce)
    {:ok, %{doc: Document.new(), site: {node(), incarnation}, interval: interval}}
  end

  @impl true
  def handle_call({:insert, index, char}, _from, s), do: local(Document.insert(s.doc, index, char, s.site), s)
  def handle_call({:delete, index}, _from, s), do: local(Document.delete(s.doc, index), s)
  def handle_call(:text, _from, s), do: {:reply, Document.text(s.doc), s}
  def handle_call(:state, _from, s), do: {:reply, Document.state(s.doc), s}
  def handle_call(_, _from, s), do: {:reply, {:error, :unknown_call}, s}

  @impl true
  def handle_cast(message, s), do: receive_state(message, s)

  @impl true
  def handle_info(:sync, s) do
    broadcast(Document.state(s.doc))
    Process.send_after(self(), :sync, s.interval)
    {:noreply, s}
  end
  def handle_info(:announce, s) do
    broadcast(Document.state(s.doc))
    {:noreply, s}
  end
  def handle_info({:nodeup, _}, s), do: handle_info(:announce, s)
  def handle_info(message, s), do: receive_state(message, s)

  defp receive_state(message, s) do
    case Protocol.decode(message) do
      {:ok, delta} -> {:noreply, %{s | doc: Document.merge(s.doc, delta)}}
      :ignore -> {:noreply, s}
    end
  end
  defp local({:error, _} = error, s), do: {:reply, error, s}
  defp local({:ok, doc, delta}, s) do
    broadcast(delta)
    {:reply, :ok, %{s | doc: doc}}
  end
  defp broadcast(delta) do
    message = Protocol.encode(delta)
    for peer <- Node.list(), do: :erlang.send({:cpd_doc, peer}, message, [:noconnect, :nosuspend])
    :ok
  end
end
