defmodule DIA.Agent.Tool do
  @moduledoc """
  Behaviour contract for all agent tool modules.

  Tools must:
  - Start via `start_link/1` using a map with at least a `:reg_key`
  - Register themselves using `{:via, Registry, ...}`
  - Support at least one `handle_call({function, [args]}, ...)`
  - Optionally implement `:describe` for self-inspection

  Example:

      defmodule DIA.Agent.QueryParser do
        @behaviour DIA.Agent.Tool

        def start_link(%{reg_key: key} = args) do
          GenServer.start_link(__MODULE__, args, name: via_tuple(key))
        end
      end
  """

  @typedoc "Unique key used to register the tool process"
  @type reg_key :: {module(), String.t(), String.t()}

  @typedoc "Standard start args passed to each agent"
  @type start_args :: %{
          required(:reg_key) => reg_key(),
          optional(:user_id) => String.t(),
          optional(:session_id) => String.t(),
          optional(any()) => any()
        }

  @callback start_link(start_args()) :: GenServer.on_start()

  @doc """
  Optional introspection entrypoint.

  If implemented, should return the MCP-compatible metadata as defined in TypeRegistry.
  """
  @callback describe() :: map() | {:ok, map()} | {:error, term()}
end
