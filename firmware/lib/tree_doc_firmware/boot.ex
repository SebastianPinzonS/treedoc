defmodule TreeDocFirmware.Boot do
  @moduledoc "Starts distribution and the replica after acquiring IPv4; retains both during Wi-Fi outages."
  use GenServer
  require Logger

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(_) do
    send(self(), :poll)
    {:ok, %{ip: nil}}
  end

  @impl true
  def handle_info(:poll, state) do
    Process.send_after(self(), :poll, 2_000)

    ip =
      Enum.find_value(["wlan0", "eth0"], fn interface ->
        addresses = VintageNet.get(["interface", interface, "addresses"]) || []

        Enum.find_value(addresses, fn
          %{family: :inet, address: {169, 254, _, _}} -> nil
          %{family: :inet, address: ip} -> ip
          _ -> nil
        end)
      end)

    case {state.ip, ip} do
      {nil, nil} ->
        {:noreply, state}

      {nil, ip} ->
        :ok = distribution(ip)
        :ok = File.mkdir_p("/data/tree_doc")

        path =
          Path.join(
            "/data/tree_doc",
            Base.url_encode64(Atom.to_string(node()), padding: false) <> ".etf"
          )

        {:ok, _} =
          Supervisor.start_link(
            [
              {TreeDoc.Replica, path: path},
              {Task.Supervisor, name: TreeDocFirmware.Tasks},
              {TreeDocFirmware.Discovery, ip: ip}
            ],
            strategy: :one_for_one
          )

        Logger.info("Tree Doc ready: #{node()}; history at #{path}")
        {:noreply, %{state | ip: ip}}

      {old, new} when new != nil and old != new ->
        Logger.warning(
          "IP changed to #{inspect(new)}. Reserve a DHCP address and restart to update the node name."
        )

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp distribution(ip) do
    if not Node.alive?() do
      {_, 0} = System.cmd("epmd", ["-daemon"], stderr_to_stdout: true)
      {:ok, _} = Node.start(String.to_atom("doc@#{:inet.ntoa(ip)}"), :longnames)
    end

    true = Node.set_cookie(:cpd2026)
    :ok
  end
end
