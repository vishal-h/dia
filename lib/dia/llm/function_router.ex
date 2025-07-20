# lib/dia/llm/function_router.ex
defmodule DIA.LLM.FunctionRouter do
  @moduledoc """
  Routes OpenAI-style function calls to the corresponding agent module & function.
  """

  alias DIA.Agent

  @type function_name :: String.t()
  @type input_args :: map()
  @type user_id :: String.t()
  @type session_id :: String.t()

  @doc """
  Routes a function call (like "query_parser_parse") to the appropriate agent.

  Example:
      route("query_parser_parse", %{"query" => "hi"}, "u1", "s1")
  """
  @spec route(function_name(), input_args(), user_id(), session_id()) ::
          {:ok, any()} | {:error, term()}
  def route(func_name, args, user_id, session_id) when is_map(args) do
    case parse_function_name(func_name) do
      {:ok, {agent_type, function}} ->
        Agent.dispatch_by_type(agent_type, function, [args], user_id, session_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec parse_function_name(function_name()) :: {:ok, {atom(), atom()}} | {:error, :invalid_format}
  def parse_function_name(func_name) do
    case String.split(func_name, ":", parts: 2) do
      [agent_str, func_str] ->
        {:ok, {String.to_atom(agent_str), String.to_atom(func_str)}}

      _ ->
        {:error, :invalid_format}
    end
  end
end
