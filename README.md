# DIA

**Distributed Intelligence Agency**


```elixir

iex>:observer.start()

iex> DIA.Agent.QueryParser.describe()

iex> for i <- 1..3, j <- 1..3, do: DIA.Agent.dispatch_by_type(:query_parser, :parse, [%{"query" => " hello world #{i}#{j} ! "}], i, j)

iex> for i <- 1..2, j <- 1..2, k <- 1..2, do: DIA.Agent.dispatch_by_type(:query_parser, :parse, [%{"query" => " hello world user:#{i} chat_session:#{j} login_session#{k} ! "}], i, j,k)

iex> DIA.Agent.TypeRegistry.get(:query_parser)
{:ok, %{name: :query_parser, module: DIA.Agent.QueryParser, ...}}

iex> DIA.Agent.TypeRegistry.get_module(:document_classifier)
{:ok, DIA.Agent.DocClassifier}

iex> DIA.Agent.TypeRegistry.get_function(:query_parser, :parse)
{:ok,
 %{
   description: "Tokenizes and normalizes a natural language query.",
   parameters: %{type: :object, properties: %{query: %{type: :string}}, required: [:query]},
   returns: %{type: :array, items: %{type: :string}}
 }}

iex> DIA.Agent.TypeRegistry.list()
[
  {:query_parser, %{...}},
  {:document_classifier, %{...}}
]

iex> DIA.Agent.TypeRegistry.raw()

# Asking the agent to describe itself (via MCP-style)
iex> {:ok, pid} = DIA.Agent.resolve_pid(DIA.Agent.QueryParser, "u1", "s1")
iex> GenServer.call(pid, :describe)
%{
  name: :query_parser,
  module: DIA.Agent.QueryParser,
  description: "Parses natural language queries.",
  functions: %{
    parse: %{
      description: "Tokenizes and normalizes a natural language query.",
      parameters: %{...},
      returns: %{...}
    }
  }
}

# Alternatively, use dispatch for :describe
iex> DIA.Agent.dispatch_by_type(:query_parser, :describe, [], "u1", "s1")
{:ok,
 %{
   name: :query_parser,
   module: DIA.Agent.QueryParser,
   description: "Parses natural language queries.",
   functions: %{...}
 }}

```

```elixir

iex> DIA.LLM.FunctionExporter.export_all()
iex> IO.puts DIA.LLM.FunctionExporter.to_json()
iex> DIA.LLM.FunctionExporter.build_func_name(:query_parser, :parse)

iex> DIA.LLM.FunctionRouter.route("query_parser:parse",%{"query" => "Hello world!"},1,1,1)

iex> mix llm_trace DIA.LLM.FunctionRouter.route/4 --name=query_parser --verbose

iex> mix llm_trace DIA.LLM.FunctionExporter.export_all/0 --name=function_exporter --ai

iex> mix llm_trace DIA.LLM.FunctionExporter.to_json/0 --name=function_exporter_json --ai

iex> mix llm_trace DIA.LLM.FunctionRouter.route/4 --runtime --name=runtime_test --verbose

iex> mix llm_trace DIA.LLM.FunctionRouter.route/4 --ai --runtime --name=runtime_test --verbose

iex> mix llm_ingest --feature=query_parser

iex> mix llm_ingest --feature=function_exporter

iex> mix llm_ingest --feature=function_exporter_json

iex> mix llm_workflow --feature=query_parser --type=bug --ai --ai-provider=openrouter --ai-model=qwen/qwen3-235b-a22b-07-25:free  --no-dry-run


```
**Naming**

Top-level children (DIA.Director, DIA.LLM, DIA.Tools): `name: __MODULE__` (simpler, faster)

Reserve `:via Registry` for dynamically created processes (e.g., agents under DIA.Director).

**notes**

  - Use :permanent (default) for infrastructure (e.g., registries, DB pools).
  - Use :transient for workers with cleanup logic (like your QueryParser).
  - Use :temporary for one-off tasks (e.g., HTTP requests).

**zz**
  - throw away code

```elixir
    children = [
      # Starts a worker by calling: DIA.Worker.start_link(arg)
      # {DIA.Worker, arg}
      {Registry, keys: :unique, name: :dia_registry}, # Registry for process names
      {DIA.Director, [name: {:via, Registry, {:dia_registry, "director"}}]}, # Director for managing agents - Dyn Supervisor
      {DIA.LLM, [name: :llm]}, # LLM for agentic tasks - Supervisor
      {DIA.Tools, [name: :tools]} # Tools for agentic tasks - GenServer
    ]


GenServer.start_link(__MODULE__, args, name: {:via, Registry, {DIA.AgentRegistry, unique_name}})


    arg = %{
      monitor_pid: monitor_pid,
      reg_key: reg_key,
      data: %{
        section: section,
        subjects: subjects,
        section_index: section_index,
        rules_to_apply: rules_to_apply
      }
    }


iex(1)> user_id=1
1
iex(2)> session_id=1
1
iex(3)> reg_key = :"DIA.Agent.QueryParser:#{user_id}_#{session_id}"
:"DIA.Agent.QueryParser:1_1"
iex(4)> DIA.Agent.query_parser(user_id, session_id)
{:ok, #PID<0.151.0>}
iex(5)> DIA.Agent.QueryParser.parse(reg_key, "Hello, how         are you!  ")
{:ok, ["hello,", "how", "are", "you!"]}


  def parse(reg_key, query) when is_binary(query) do
    GenServer.call(via_tuple(reg_key), {:parse, query})
  end

  def parse(_), do: {:error, "Invalid query format"}


  def parse(query, user_id, session_id) do
    case resolve(DIA.Agent.QueryParser, user_id, session_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:parse, query})

      {:error, reason} ->
        Logger.error("Failed to resolve agent: #{inspect(reason)}")
        {:error, reason}
    end
  end

```
