%{
  "agent" => %{
    include: "lib/dia/application.ex,lib/dia/agent/**,lib/dia/llm/**",
    exclude: "**/*_test.exs"
  },
  "query_parser" => %{
    exclude: "**/*_test.exs",
    include: "lib/dia/agent/dynamic_supervisor.ex,lib/dia/agent.ex,lib/dia/agent/type_registry.ex,lib/dia/llm/function_router.ex,lib/dia/agent/reg_key.ex,test/dia/agent/dynamic_supervisor_test.exs,test/dia/agent_test.exs,test/dia/agent/type_registry_test.exs,test/dia/llm/function_router_test.exs,test/dia/agent/reg_key_test.exs",
    description: "The DynamicQueryProcessor feature is responsible for managing the parsing and routing of queries to various functions within the system. It utilizes a dynamic supervisor to manage the lifecycle of processes that handle state management and type registration for different query types. The feature allows for flexible request routing based on the function definitions registered in the TypeRegistry, facilitating efficient query handling and state management.",
    related_modules: ["DIA.QueryParser", "DIA.Agent.QueryHandler"],
    complexity: "medium",
    patterns: ["GenServer", "Supervisor", "Registry"],
    recommendations: ["Consider consolidating lightweight state management modules (DIA.Agent, DIA.Agent.TypeRegistry, DIA.Agent.RegKey) into a single context to reduce complexity and improve maintainability.",
     "Implement more comprehensive documentation and comments within the codebase to clarify the purpose and interactions of each module, especially for new developers."],
    suggested_name: "DynamicQueryProcessor"
  }
}

# # Use a predefined feature
# mix llm_ingest --feature=agent

# # Combine feature with additional excludes
# mix llm_ingest --feature=agent --exclude="**/old_*.ex"

# # Override feature include with custom patterns
# mix llm_ingest --feature=agent --include="lib/agent/specific_file.ex"

# example configuration for `llm_features.ex` to include/exclude specific directories and files
# This file is used to define which parts of the codebase should be included or excluded
# when generating LLM function metadata or during other processing tasks.
# The patterns can be used to filter files based on their paths.
# The patterns support glob syntax for matching file paths.
# %{
#   "auth" => %{
#     include: "lib/auth/**,test/auth/**,priv/repo/migrations/*_auth_*",
#     exclude: "**/*_test.exs"
#   },
#   "api" => %{
#     include: "lib/api/**,lib/schemas/**,test/api/**"
#   },
#   "frontend" => %{
#     include: "assets/**,lib/*_web/**,test/*_web/**"
#   },
#   "payments" => %{
#     include: "lib/payments/**,lib/billing/**,test/payments/**,test/billing/**",
#     exclude: "lib/payments/legacy/**"
#   }
#}
