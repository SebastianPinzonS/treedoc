defmodule TreeDocFirmware.Discovery do
  @moduledoc "Finds EPMD on the laboratory /24 and retries every 10 s without assuming peer node prefixes."
  use GenServer
  require Logger

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def hosts({a, b, c, d}), do: for(n <- 1..254, n != d, do: {a, b, c, n})

  # EPMD response: EPMD port (32 bits), followed by name records.
  def names(<<4369::32, body::binary>>) when byte_size(body) <= 8192 do
    Regex.scan(~r/^name ([A-Za-z0-9_-]{1,64}) at port [0-9]+\r?$/m, body)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.take(16)
  end

  def names(_), do: []

  @impl true
  def init(opts) do
    send(self(), :scan)
    {:ok, %{ip: Keyword.fetch!(opts, :ip), task: nil}}
  end

  @impl true
  def handle_info(:scan, %{task: nil} = s) do
    task =
      Task.Supervisor.async_nolink(TreeDocFirmware.Tasks, fn ->
        hosts(s.ip)
        |> Task.async_stream(&connect_host/1,
          max_concurrency: 32,
          timeout: 5_000,
          on_timeout: :kill_task
        )
        |> Stream.run()
      end)

    {:noreply, %{s | task: task}}
  end

  def handle_info({ref, _}, %{task: %Task{ref: ref}} = s) do
    Process.demonitor(ref, [:flush])
    Process.send_after(self(), :scan, 10_000)
    {:noreply, %{s | task: nil}}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, %{task: %Task{ref: ref}} = s) do
    Logger.warning("Discovery will retry: #{inspect(reason)}")
    Process.send_after(self(), :scan, 10_000)
    {:noreply, %{s | task: nil}}
  end

  defp connect_host(ip) do
    case :gen_tcp.connect(ip, 4369, [:binary, active: false], 300) do
      {:ok, socket} ->
        candidates =
          try do
            :ok = :gen_tcp.send(socket, <<1::16, 110>>)
            read(socket, <<>>, System.monotonic_time(:millisecond) + 500) |> names()
          after
            :gen_tcp.close(socket)
          end

        for name <- candidates do
          peer = String.to_atom("#{name}@#{:inet.ntoa(ip)}")

          if peer != node() and peer not in Node.list() and Node.connect(peer),
            do: Logger.info("Tree Doc connected to #{peer}")
        end

      _ ->
        :ok
    end
  end

  defp read(socket, acc, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 or byte_size(acc) > 8192 do
      <<>>
    else
      case :gen_tcp.recv(socket, 0, remaining) do
        {:ok, bytes} -> read(socket, acc <> bytes, deadline)
        {:error, :closed} -> acc
        _ -> <<>>
      end
    end
  end
end
