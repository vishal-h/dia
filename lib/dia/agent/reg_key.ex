defmodule DIA.Agent.RegKey do
  @moduledoc """
  A structured identifier for uniquely registering agent processes.

  Fields:
    - :agent_type — the agent module (e.g., DIA.Agent.WorkflowPlanner)
    - :user_id — user identity
    - :login_session_id — optional login/session token
    - :chat_session_id — thread or conversation identifier
  """

  @enforce_keys [:agent_type, :user_id, :chat_session_id]
  defstruct [
    :agent_type,
    :user_id,
    :chat_session_id,
    login_session_id: nil
  ]

  @type t :: %__MODULE__{
          agent_type: module(),
          user_id: String.t(),
          login_session_id: String.t() | nil,
          chat_session_id: String.t()
        }

  @doc """
  Converts a RegKey into a Registry-compatible tuple for via-tuple registration.
  """
  @spec to_registry_key(t()) :: {module(), String.t(), String.t(), String.t() | nil}
  def to_registry_key(%__MODULE__{agent_type: mod, user_id: u, chat_session_id: c, login_session_id: l}) do
    {mod, u, c, l}
  end
end
