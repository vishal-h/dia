defmodule DIA.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: DIA.Worker.start_link(arg)
      # {DIA.Worker, arg}

      {Registry, keys: :unique, name: DIA.Agent.Registry},
      {Registry, keys: :unique, name: :chat_registry},
      {Registry, keys: :unique, name: :workflow_registry},

      {DIA.LLM.Supervisor, []},
      {DIA.Tool.Supervisor, []},

      {DIA.Agent.DynamicSupervisor, []},
      {DIA.Chat.DynamicSupervisor, []},
      {DIA.Workflow.DynamicSupervisor, []},

      {DIA.Director, []}

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DIA.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
