defmodule DIA.MixProject do
  use Mix.Project

  def project do
    [
      app: :dia,
      version: "0.1.0",
      description: "Distributed Intelligent Agents",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :observer, :wx],
      mod: {DIA.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:jason, "~> 1.4"},
      {:joken, "~> 2.6"},
      {:req, "~> 0.4"},
      {:finch, "~>0.20.0"}
    ]
  end
end
