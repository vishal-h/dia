defmodule DIA.Chat.Session do
  @moduledoc """
  Represents a chat conversation session for a user.

  A ChatSession combines authentication (via JWT claims) with conversation
  state (context and metadata). It supports both development and production
  environments seamlessly.

  ## Examples

      # Development usage
      iex> session = DIA.Chat.Session.new("user_123")
      iex> DIA.Chat.Session.user_id(session)
      "user_123"

      # Production usage (from HTTP request)
      iex> DIA.Chat.Session.from_request(auth_token, "chat_abc123")
      {:ok, %DIA.Chat.Session{}}
  """

  defstruct [:chat_id, :claims, :context, :metadata]

  # Development constructor
  def new(user_id, opts \\ []) do
    # Create login session token (reusing your existing Auth flow)
    login_session_id = Keyword.get(opts, :login_session_id, "dev_login")

    {:ok, _token, claims}  =
      DIA.Auth.Token.encode(%{"user_id" => user_id, "login_session_id" => login_session_id})

    # {:ok, claims} = DIA.Auth.Token.decode(token)

    %__MODULE__{
      chat_id:
        Keyword.get(
          opts,
          :chat_id,
          Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
        ),
      claims: claims,
      context: Keyword.get(opts, :context, []),
      metadata: %{}
    }
  end

  # Production constructor (from HTTP request)
  def from_request(auth_token, chat_id) do
    case DIA.Auth.Token.decode(auth_token) do
      {:ok, claims} ->
        {:ok,
         %__MODULE__{
           chat_id: chat_id,
           claims: claims,
           # Load from persistence
           context: [],
           metadata: %{}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # API for Chat module
  def user_id(%__MODULE__{claims: claims}), do: claims["user_id"]
  def login_session_id(%__MODULE__{claims: claims}), do: claims["login_session_id"]
  def chat_id(%__MODULE__{chat_id: id}), do: id
  def get_context(%__MODULE__{context: context}), do: context

  def update_context(%__MODULE__{} = session, new_context) do
    %{session | context: new_context}
  end

  def update_metadata(%__MODULE__{} = session, key, value) do
    new_metadata = Map.put(session.metadata, key, value)
    %{session | metadata: new_metadata}
  end
end
