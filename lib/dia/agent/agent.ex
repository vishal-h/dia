defmodule DIA.Agent do
  @moduledoc """
  Agent dispatch and lifecycle manager.

  Supports resolving agents by symbolic type and invoking their supported functions.
  """

  require Logger

  @registry DIA.Agent.Registry
  @dynamic_supervisor DIA.Agent.DynamicSupervisor

  alias DIA.Agent.TypeRegistry

  @type agent_type :: atom()
  @type agent_function :: atom()
  @type input :: any()
  @type user_id :: String.t()
  @type session_id :: String.t()

  @doc """
  Dispatches a function on an agent given its symbolic type.

  Does not perform validation — assumes caller is trusted or validated.
  """
  @spec dispatch_by_type(agent_type(), agent_function(), [any()], user_id(), session_id()) ::
          {:ok, any()} | {:error, term()}
  def dispatch_by_type(agent_type, function, args, user_id, session_id) do
    with {:ok, %{module: mod}} <- TypeRegistry.get(agent_type),
         {:ok, pid} <- resolve_pid(mod, user_id, session_id) do

      Logger.metadata(agent: to_string(agent_type), user_id: user_id, session_id: session_id)
      GenServer.call(pid, {function, args})
    else
      {:error, reason} ->
        Logger.error("Dispatch failed for #{agent_type}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Resolves or starts a new agent process based on module, user ID, and session ID.
  """
  @spec resolve_pid(module(), user_id(), session_id()) :: {:ok, pid()} | {:error, term()}
  def resolve_pid(agent_module, user_id, session_id) do
    reg_key = {agent_module, user_id, session_id}

    args = %{
      reg_key: reg_key,
      user_id: user_id,
      session_id: session_id
    }

    case Registry.lookup(@registry, reg_key) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        child_spec = %{
          id: make_ref(),
          start: {agent_module, :start_link, [args]},
          restart: :transient
        }

        DynamicSupervisor.start_child(@dynamic_supervisor, child_spec)
    end
  end

  @doc """
  Optional: validate input before dispatching.

  Can be enhanced with JSON Schema validator.
  """
  @spec validate_and_dispatch(agent_type(), agent_function(), map(), user_id(), session_id()) ::
          {:ok, any()} | {:error, term()}
  def validate_and_dispatch(type, func, input_map, user_id, session_id) when is_map(input_map) do
    with {:ok, func_meta} <- TypeRegistry.get_function(type, func),
         :ok <- validate_input(func_meta.parameters, input_map),
         do: dispatch_by_type(type, func, [input_map], user_id, session_id)
  end

  defp validate_input(_schema, _input), do: :ok  # stub

  @doc "Lists all available agent types and their metadata."
  def list_available_agents, do: TypeRegistry.list()
end
