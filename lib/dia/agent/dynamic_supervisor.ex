defmodule DIA.Agent.DynamicSupervisor do
  @moduledoc """
  DynamicSupervisor for managing agent processes.
  """
  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def terminate(reason, _state) do
    Logger.info ("terminating: #{inspect(self())}: #{inspect(reason)}")
    :ok
  end

end
