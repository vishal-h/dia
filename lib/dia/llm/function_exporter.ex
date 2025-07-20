# lib/dia/llm/function_exporter.ex
defmodule DIA.LLM.FunctionExporter do
  @moduledoc """
  Exports DIA agent tools and functions in OpenAI-compatible function-calling format.
  """

  alias DIA.Agent.TypeRegistry

  @type openai_function_spec :: %{
          name: String.t(),
          description: String.t(),
          parameters: map()
        }

  @doc """
  Returns a list of OpenAI function specs for all registered agent tools.
  """
  @spec export_all() :: [openai_function_spec()]
  def export_all do
    TypeRegistry.list()
    |> Enum.flat_map(fn {agent_type, %{functions: funcs}} ->
      Enum.map(funcs, fn {func_name, meta} ->
        %{
          name: build_func_name(agent_type, func_name),
          description: meta.description,
          parameters: meta.parameters
        }
      end)
    end)
  end

  @doc """
  Builds a stable function name like "query_parser_parse"
  """
  @spec build_func_name(atom(), atom()) :: String.t()
  def build_func_name(agent_type, func_name) do
    "#{agent_type}:#{func_name}"
  end

  @doc """
  Returns a JSON string of all exported function specs.
  """
  def to_json do
    export_all()
    |> Jason.encode!(pretty: true)
  end
end
