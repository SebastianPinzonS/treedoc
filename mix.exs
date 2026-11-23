defmodule TreedocEquipo.MixProject do
  use Mix.Project
  def project, do: [app: :treedoc_equipo, version: "0.1.0", elixir: "~> 1.18", deps: []]
  def application, do: [extra_applications: [:logger, :crypto], mod: {TreedocEquipo.Application, []}]
end
