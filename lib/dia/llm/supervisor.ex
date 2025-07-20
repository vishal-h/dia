defmodule DIA.LLM.Supervisor do
  @moduledoc """
  DIA.LLM is a Supervisor responsible for managing LLM-related processes in the DIA application.
  """
  # Automatically defines child_spec/1
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    Supervisor.init([], strategy: :one_for_one)
  end

  def terminate(reason, _state) do
    Logger.info ("terminating: #{inspect(self())}: #{inspect(reason)}")
    :ok
  end


end
