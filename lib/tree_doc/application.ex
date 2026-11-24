defmodule TreeDoc.Application do
  use Application
  @impl true
  def start(_type, _args) do
    Supervisor.start_link([{TreeDoc.Replica, []}],
      strategy: :one_for_one,
      name: TreeDoc.Supervisor
    )
  end
end
