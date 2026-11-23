defmodule TreedocEquipo.Application do
  use Application
  @impl true
  def start(_type, _args) do
    Supervisor.start_link([{TreedocEquipo.Replica, []}], strategy: :one_for_one, name: TreedocEquipo.Supervisor)
  end
end
