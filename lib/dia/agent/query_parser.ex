defmodule DIA.Agent.QueryParser do
  @moduledoc """
  Parses and tokenizes natural language queries.
  """
  use GenServer, restart: :transient

  @timeout 60_000
  use DIA.Agent.Describable, type: :query_parser

  @behaviour DIA.Agent.Tool

  @registry DIA.Agent.Registry

  require Logger

  @impl true
  def start_link(%{reg_key: reg_key} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(reg_key))
  end

  defp via_tuple(key), do: {:via, Registry, {@registry, key}}

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state, @timeout}
  end

  @impl true
  def handle_info(:timeout, state), do: {:stop, :normal, state}

  @impl true
  def terminate(reason, %{reg_key: key}) do
    Logger.info("Terminating QueryParser #{inspect(key)}: #{inspect(reason)}")
    :ok
  end

  @impl true
  def handle_call({:parse, [%{"query" => query}]}, _from, state) do
    result = parse_query(query)
    {:reply, {:ok, result}, state, @timeout}
  end

  # @impl true
  # def handle_call(:describe, _from, state) do
  #   {:ok, meta} = DIA.Agent.TypeRegistry.get(:query_parser)
  #   {:reply, meta, state, @timeout}
  # end

  defp parse_query(nil), do: []

  defp parse_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.downcase/1)
  end
end
