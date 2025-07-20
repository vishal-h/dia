defmodule DIA.Agent.TypeRegistry do
  @moduledoc """
  Holds metadata for all available pluggable agent types in the system.

  Inspired by MCP (Model-Context Protocol), this registry enables
  programmatic introspection and invocation of tools (agents) with typed metadata.
  """

  @typedoc "The symbolic name used to refer to an agent tool"
  @type agent_type :: atom()

  @typedoc "The name of a function exposed by an agent"
  @type agent_function :: atom()

  @typedoc "JSON-compatible type specification"
  @type json_schema :: %{
          optional(:type) => atom(),
          optional(:description) => String.t(),
          optional(:properties) => map(),
          optional(:items) => json_schema,
          optional(:required) => list(atom())
        }

  @typedoc "Function metadata for agent tool"
  @type function_metadata :: %{
          description: String.t(),
          parameters: json_schema,
          returns: json_schema
        }

  @typedoc "Full metadata for an agent"
  @type metadata :: %{
          name: agent_type(),
          module: module(),
          description: String.t(),
          functions: %{required(agent_function()) => function_metadata()}
        }

  # -------------------------------
  # Registry of available agent tools
  # -------------------------------
  @agent_types %{
    query_parser: %{
      name: :query_parser,
      module: DIA.Agent.QueryParser,
      description: "Parses natural language queries.",
      functions: %{
        parse: %{
          description: "Tokenizes and normalizes a natural language query.",
          parameters: %{
            type: :object,
            properties: %{
              query: %{type: :string, description: "Text query"}
            },
            required: [:query]
          },
          returns: %{
            type: :array,
            items: %{type: :string}
          }
        }
      }
    },
    document_classifier: %{
      name: :document_classifier,
      module: DIA.Agent.DocClassifier,
      description: "Classifies documents into predefined categories.",
      functions: %{
        classify: %{
          description: "Classifies raw text into a known domain or label.",
          parameters: %{
            type: :object,
            properties: %{
              text: %{type: :string, description: "Input document text"}
            },
            required: [:text]
          },
          returns: %{
            type: :string
          }
        }
      }
    }
  }

  # -------------------------------
  # Public API
  # -------------------------------

  @doc "Returns full metadata for a given agent type"
  @spec get(agent_type()) :: {:ok, metadata()} | {:error, :unknown_type}
  def get(type) do
    case Map.get(@agent_types, type) do
      nil -> {:error, :unknown_type}
      meta -> {:ok, meta}
    end
  end

  @doc "Returns the module for a given agent type"
  @spec get_module(agent_type()) :: {:ok, module()} | {:error, :unknown_type}
  def get_module(type) do
    with {:ok, %{module: mod}} <- get(type), do: {:ok, mod}
  end

  @doc "Returns metadata for a specific function of an agent"
  @spec get_function(agent_type(), agent_function()) ::
          {:ok, function_metadata()} | {:error, :unknown_type | :function_not_found}
  def get_function(agent_type, function_name) do
    with {:ok, %{functions: funcs}} <- get(agent_type),
         {:ok, func_meta} <- Map.fetch(funcs, function_name) do
      {:ok, func_meta}
    else
      :error -> {:error, :function_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the list of all agent types and their metadata"
  @spec list() :: [{agent_type(), metadata()}]
  def list do
    Map.to_list(@agent_types)
  end

  @doc "Returns the full raw map of all agents (for introspection or serialization)"
  @spec raw() :: %{agent_type() => metadata()}
  def raw, do: @agent_types
end
