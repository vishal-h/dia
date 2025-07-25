# Auto-generated LLM feature configuration
# Generated by: mix llm_trace
# Features: function_exporter, function_exporter_json, query_parser, runtime_test

%{
  "function_exporter" => %{
    exclude: "**/*_test.exs",
    include: "lib/dia/agent/query_parser.ex,lib/dia/agent/type_registry.ex,lib/dia/llm/function_exporter.ex,test/dia/agent/query_parser_test.exs,test/dia/agent/type_registry_test.exs,test/dia/llm/function_exporter_test.exs",
    description: "The FunctionIntegrationManager feature facilitates the integration of large language models (LLMs) with a focus on managing and exporting functions. It utilizes lightweight state management through the QueryParser and TypeRegistry modules to handle queries and maintain a registry of types, ensuring that the LLM can effectively process and respond to various function calls based on user input.",
    related_modules: ["DIA.Agent.FunctionHandler", "DIA.LLM.ResponseFormatter",
     "DIA.LLM.FunctionRegistry"],
    complexity: "medium",
    patterns: ["GenServer", "Context", "State Management"],
    recommendations: ["Consider implementing a Supervisor to manage the lifecycle of the QueryParser and TypeRegistry modules, enhancing fault tolerance and supervision.",
     "Refactor the QueryParser and TypeRegistry to use a common behavior or protocol if they share similar functionalities, promoting code reuse and reducing duplication."],
    suggested_name: "FunctionIntegrationManager"
  },
  "function_exporter_json" => %{
    exclude: "**/*_test.exs",
    include: "lib/dia/agent/query_parser.ex,lib/dia/agent/type_registry.ex,lib/dia/llm/function_exporter.ex,test/dia/agent/query_parser_test.exs,test/dia/agent/type_registry_test.exs,test/dia/llm/function_exporter_test.exs",
    description: "Auto-generated from code tracing function_exporter_json"
  },
  "query_parser" => %{
    exclude: "**/*_test.exs",
    include: "lib/dia/agent/dynamic_supervisor.ex,lib/dia/agent.ex,lib/dia/agent/type_registry.ex,lib/dia/llm/function_router.ex,lib/dia/agent/reg_key.ex,test/dia/agent/dynamic_supervisor_test.exs,test/dia/agent_test.exs,test/dia/agent/type_registry_test.exs,test/dia/llm/function_router_test.exs,test/dia/agent/reg_key_test.exs",
    description: "The DynamicAgentManagement feature provides a structured approach to managing lightweight agents within a dynamic supervision framework. It includes modules for process supervision, state management, and request routing, allowing for efficient handling of various agent types and their interactions. The feature enables the registration and management of agent types, facilitating dynamic function routing based on incoming requests, which is particularly useful for applications requiring flexible and scalable state management.",
    related_modules: ["DIA.AgentSupervisor", "DIA.AgentRegistry"],
    complexity: "medium",
    patterns: ["GenServer", "Supervisor", "Registry", "Routing"],
    recommendations: ["Consider consolidating state management modules if they share similar functionality to reduce redundancy.",
     "Enhance documentation for each module to clarify their roles and interactions, improving maintainability and onboarding for new developers."],
    suggested_name: "DynamicAgentManagement"
  },
  "runtime_test" => %{
    exclude: "**/*_test.exs",
    include: "lib/dia/agent/dynamic_supervisor.ex,lib/dia/agent.ex,lib/dia/agent/type_registry.ex,lib/dia/llm/function_router.ex,lib/dia/agent/reg_key.ex,test/dia/agent/dynamic_supervisor_test.exs,test/dia/agent_test.exs,test/dia/agent/type_registry_test.exs,test/dia/llm/function_router_test.exs,test/dia/agent/reg_key_test.exs",
    description: "The DynamicAgentManagement feature provides a framework for managing lightweight agents in a concurrent environment. It includes a dynamic supervisor for process supervision, a registry for managing agent types, and a function router for directing requests to the appropriate agents. This setup allows for efficient state management and dynamic process handling, enabling the system to scale and adapt to varying workloads.",
    related_modules: ["DIA.AgentSupervisor", "DIA.AgentManager"],
    complexity: "medium",
    patterns: ["GenServer", "Supervisor", "Registry", "Routing"],
    recommendations: ["Consider consolidating the lightweight state management modules (DIA.Agent, DIA.Agent.TypeRegistry, DIA.Agent.RegKey) into a single context to reduce redundancy and improve clarity.",
     "Implement more comprehensive documentation and examples for each module to enhance maintainability and onboarding for new developers."],
    suggested_name: "DynamicAgentManagement"
  }
}
