defmodule TreeDoc.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :tree_doc,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [{:bandit, "~> 1.8"}, {:plug, "~> 1.18"}, {:jason, "~> 1.4"}]
    ]

  def application,
    do: [extra_applications: [:logger, :crypto], mod: {TreeDoc.Application, []}]
end
