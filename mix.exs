defmodule Khepri.MixProject do
  use Mix.Project

  def project do
    [
      app: :khepri,
      description: "Tree-like replicated on-disk database library",
      version: "0.2.1",
      language: :erlang,
      deps: deps()
    ]
  end

  defp deps() do
    [
      # Dependency pinning must be updated in rebar.config too.
      {:ra, "2.0.4"}
    ]
  end
end
