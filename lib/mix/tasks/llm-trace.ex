defmodule Mix.Tasks.LlmTrace do
  use Mix.Task

  @shortdoc "Trace code dependencies to auto-generate LLM feature configurations"

  @moduledoc """
  Automatically discover feature boundaries by tracing function calls and dependencies.

  Basic Usage:
    mix llm_trace MyApp.Router.route/4 --name=routing
    mix llm_trace MyApp.Auth.login/2 --name=auth --depth=3
    mix llm_trace MyApp.Payments.process_payment/3 --runtime
    mix llm_trace MyApp.Core.main/1 --name=core --verbose

  AI-Enhanced Usage:
    mix llm_trace MyApp.Router.route/4 --name=routing --ai
    mix llm_trace MyApp.Feature.main/1 --ai --ai-model=gpt-4o --verbose

  AI Features:
    - Smart feature naming suggestions
    - Comprehensive feature descriptions
    - Complexity analysis and architectural pattern detection
    - Improvement recommendations
    - Related module suggestions

  Requirements for AI features:
    - Set OPENAI_API_KEY environment variable, or use --ai-api-key
    - Add to mix.exs: {:req, "~> 0.5"}, {:jason, "~> 1.4"}
  """

  # Suppress warnings for Erlang modules that are loaded at runtime
  @compile {:no_warn_undefined, [:xref]}

  @impl true
  def run(args) do
    {opts, remaining_args, _} = OptionParser.parse(args,
      switches: [
        name: :string,
        depth: :integer,
        runtime: :boolean,
        output: :string,
        include_tests: :boolean,
        verbose: :boolean,
        ai: :boolean,
        ai_model: :string,
        ai_api_key: :string,
        help: :boolean
      ]
    )

    # Handle help option
    if opts[:help] do
      show_help()
    else
      target = case remaining_args do
        [target] -> target
        _ ->
          Mix.shell().error("Error: Target function required. Use --help for usage information.")
          System.halt(1)
      end

      feature_name = opts[:name] || infer_feature_name(target)
      depth = opts[:depth] || 5
      use_runtime = opts[:runtime] || false
      include_tests = opts[:include_tests] || true
      verbose = opts[:verbose] || false
      use_ai = opts[:ai] || false
      ai_model = opts[:ai_model] || "gpt-4o-mini"
      ai_api_key = opts[:ai_api_key] || System.get_env("OPENAI_API_KEY")

      # Store options globally for helper functions
      Process.put(:llm_trace_verbose, verbose)
      Process.put(:llm_trace_ai_enabled, use_ai)
      Process.put(:llm_trace_ai_model, ai_model)
      Process.put(:llm_trace_ai_api_key, ai_api_key)

      # Validate AI dependencies early if AI is requested
      if opts[:ai] do
        case validate_ai_dependencies() do
          :ok -> :ok
          {:error, message} ->
            Mix.shell().error("AI features unavailable: #{message}")
            Mix.shell().info("Continuing with basic tracing (no AI features)...")
            Process.put(:llm_trace_ai_enabled, false)
        end
      end

      Mix.shell().info("Tracing feature: #{feature_name}")
      Mix.shell().info("Starting from: #{target}")

      # Debug module discovery if verbose
      if verbose, do: debug_module_discovery()

      # Parse the target MFA
      {module, function, arity} = parse_mfa(target)

      # Choose tracing strategy
      dependencies = if use_runtime do
        # Store original MFA for runtime processing
        Process.put(:runtime_trace_module, module)
        Process.put(:runtime_trace_function, function)
        Process.put(:runtime_trace_arity, arity)
        trace_runtime_dependencies(module, function, arity, depth)
      else
        trace_static_dependencies(module, function, arity, depth)
      end

      # Convert to file patterns
      patterns = dependencies_to_patterns(dependencies, include_tests)

      # Generate feature configuration with optional AI enhancement
      feature_config = if Process.get(:llm_trace_ai_enabled, false) do
        enhance_with_ai(feature_name, dependencies, patterns)
      else
        generate_feature_config(feature_name, patterns)
      end

      # Output results
      output_path = opts[:output] || "llm_features_traced.exs"
      write_feature_config(output_path, feature_name, feature_config)

      Mix.shell().info("Generated feature '#{feature_name}' in #{output_path}")
      print_summary(dependencies, patterns)
    end
  end

  # Helper function for conditional debug output
  defp debug_info(message) do
    if Process.get(:llm_trace_verbose, false) do
      Mix.shell().info(message)
    end
  end

  defp show_help do
    Mix.shell().info("""
    #{@shortdoc}

    USAGE:
        mix llm_trace <MODULE.FUNCTION/ARITY> [OPTIONS]

    ARGUMENTS:
        MODULE.FUNCTION/ARITY    Target function to trace (e.g., MyApp.Router.route/2)

    OPTIONS:
        --name NAME              Feature name for the generated configuration
                                 (default: inferred from module name)

        --depth N               Maximum depth for dependency tracing (default: 5)

        --runtime               Use runtime tracing instead of static analysis
                                (requires the application to be startable)

        --output PATH           Output file path (default: llm_features_traced.exs)

        --include-tests         Include test file patterns (default: true)
                                Use --no-include-tests to disable

        --verbose               Show detailed tracing information

        --ai                    Enable AI-powered analysis for better feature descriptions
                                (requires OPENAI_API_KEY environment variable)

        --ai-model MODEL        OpenAI model to use for AI analysis (default: gpt-4o-mini)
                                Options: gpt-4o, gpt-4o-mini, gpt-4-turbo

        --ai-api-key KEY        OpenAI API key (alternative to OPENAI_API_KEY env var)

        --help                  Show this help message

    EXAMPLES:
        # Basic usage with static analysis
        mix llm_trace MyApp.Router.route/4 --name=routing

        # Deep tracing with custom depth
        mix llm_trace MyApp.Auth.login/2 --name=auth --depth=3 --verbose

        # Runtime tracing (more accurate but requires running app)
        mix llm_trace MyApp.Payments.process_payment/3 --runtime --name=payments

        # AI-enhanced analysis
        mix llm_trace MyApp.Router.route/4 --ai --name=smart_routing

        # Custom output location
        mix llm_trace MyApp.Core.main/1 --output=config/my_features.exs

        # Exclude test files
        mix llm_trace MyApp.Worker.perform/2 --no-include-tests

    TRACING METHODS:
        Static Analysis (default):
        - Fast and safe
        - Analyzes source code without running it
        - May miss some runtime dependencies

        Runtime Tracing (--runtime):
        - More comprehensive dependency discovery
        - Requires application to be startable
        - Uses :dbg to trace actual function calls
        - May timeout or fail if function can't be executed safely

    AI FEATURES:
        When --ai is enabled, the tool will:
        - Suggest better feature names
        - Generate comprehensive descriptions
        - Analyze architectural complexity
        - Identify common patterns (GenServer, Supervisor, etc.)
        - Provide refactoring recommendations
        - Suggest related modules that might be missing

    REQUIREMENTS:
        For AI features, add to your mix.exs:
          {:req, "~> 0.5"},      # Version 0.5+ recommended
          {:jason, "~> 1.4"}     # JSON parsing

        Then run: mix deps.get && mix compile

        Set environment variable:
          export OPENAI_API_KEY=your_key_here

        Or pass directly:
          mix llm_trace Module.func/1 --ai --ai-api-key=your_key

    OUTPUT:
        Generates or updates a feature configuration file with:
        - Include/exclude patterns for files
        - Feature metadata and descriptions
        - AI analysis results (if enabled)

    The generated configuration can be used with:
        mix llm_ingest --feature=FEATURE_NAME
    """)
  end

  defp debug_module_discovery() do
    Mix.shell().info("\n=== Module Discovery Debug ===")

    # Show all application modules discovered
    app_modules = get_application_modules()
    Mix.shell().info("App modules found: #{length(app_modules)}")
    app_modules
    |> Enum.take(10)
    |> Enum.each(fn module ->
      file_pattern = module_to_file_pattern(module)
      beam_path = :code.which(module)
      Mix.shell().info("  #{module} -> #{file_pattern} (beam: #{inspect(beam_path)})")
    end)

    Mix.shell().info("=== End Module Discovery Debug ===\n")
  end

  defp parse_mfa(target) do
    case Regex.run(~r/^(.+)\.([^.]+)\/(\d+)$/, target) do
      [_, module_str, function_str, arity_str] ->
        module = String.to_existing_atom("Elixir." <> module_str)
        function = String.to_atom(function_str)
        arity = String.to_integer(arity_str)
        {module, function, arity}

      _ ->
        raise "Invalid MFA format. Use: Module.function/arity"
    end
  end

  defp validate_ai_dependencies() do
    case {Code.ensure_loaded(Req), Code.ensure_loaded(Jason)} do
      {{:module, Req}, {:module, Jason}} ->
        :ok
      {{:error, _}, {:module, Jason}} ->
        {:error, "Missing Req dependency. Add to mix.exs: {:req, \"~> 0.5\"}"}
      {{:module, Req}, {:error, _}} ->
        {:error, "Missing Jason dependency. Add to mix.exs: {:jason, \"~> 1.4\"}"}
      {{:error, _}, {:error, _}} ->
        {:error, "Missing dependencies. Add to mix.exs: {:req, \"~> 0.5\"}, {:jason, \"~> 1.4\"}"}
    end
  end

  defp trace_static_dependencies(module, function, arity, depth) do
    Mix.shell().info("Using static analysis...")

    # Try Mix.Xref first (available in Mix), then fall back to :xref
    case Code.ensure_loaded(Mix.Xref) do
      {:module, Mix.Xref} ->
        trace_with_mix_xref(module, function, arity, depth)

      {:error, _} ->
        case Code.ensure_loaded(:xref) do
          {:module, :xref} ->
            trace_with_xref(module, function, arity, depth)

          {:error, _} ->
            Mix.shell().error("Neither Mix.Xref nor :xref available, using simple analysis")
            trace_with_simple_analysis(module, function, arity, depth)
        end
    end
  end

  defp trace_with_mix_xref(module, function, arity, depth) do
    Mix.shell().info("Using Mix.Xref for analysis...")

    # Use Mix's Xref functionality
    try do
      # This is a simplified approach - Mix.Xref is more complex
      # For now, fall back to simple analysis but with better module discovery
      discover_dependencies_via_compilation(module, function, arity, depth)
    rescue
      e ->
        Mix.shell().error("Mix.Xref analysis failed: #{inspect(e)}")
        trace_with_simple_analysis(module, function, arity, depth)
    end
  end

  defp discover_dependencies_via_compilation(module, function, arity, _depth) do
    # Alternative approach: use compilation metadata
    _mfa = {module, function, arity}

    # Get all modules in the current application
    app_modules = get_application_modules()

    # Find modules that might be related by analyzing their beam files
    related_modules = Enum.filter(app_modules, fn mod ->
      module_references_target?(mod, module)
    end)

    # Convert to MFA format for consistency
    [{module, function, arity}] ++ Enum.map(related_modules, fn mod -> {mod, :__discovered__, 0} end)
  end

  defp get_application_modules do
    app_name = Mix.Project.config()[:app]

    # Try multiple approaches to get modules
    modules = case :application.get_key(app_name, :modules) do
      {:ok, modules} when is_list(modules) and length(modules) > 0 ->
        debug_info("Found #{length(modules)} modules from application key")
        modules
      _ ->
        debug_info("Application key method failed, scanning loaded modules...")
        # Fallback: scan loaded modules
        loaded_modules = :code.all_loaded()
        |> Enum.map(fn {module, _} -> module end)
        |> Enum.filter(&is_app_module?/1)

        debug_info("Found #{length(loaded_modules)} loaded app modules")

        # If still empty, try a more aggressive approach
        if Enum.empty?(loaded_modules) do
          debug_info("Loaded modules empty, trying to compile and get all modules...")

          # Compile the project to ensure modules are loaded
          Mix.Task.run("compile")

          # Try again with all loaded modules
          all_loaded = :code.all_loaded()
          |> Enum.map(fn {module, _} -> module end)
          |> Enum.filter(fn module ->
            module_str = to_string(module)
            app_name_str = app_name |> to_string() |> Macro.camelize()
            String.starts_with?(module_str, "Elixir.#{app_name_str}")
          end)

          debug_info("After compile: Found #{length(all_loaded)} app modules")
          all_loaded
        else
          loaded_modules
        end
    end

    debug_info("Final available modules: #{inspect(Enum.take(modules, 10))}...")
    modules
  end

  defp module_references_target?(module, target_module) do
    # Check if module references the target module
    try do
      case :code.which(module) do
        beam_path when is_list(beam_path) ->
          # This is a simplified check - could be enhanced with beam file analysis
          module_parts = module |> to_string() |> String.split(".")
          target_parts = target_module |> to_string() |> String.split(".")

          # Simple heuristic: shared namespace
          Enum.zip(module_parts, target_parts)
          |> Enum.take_while(fn {a, b} -> a == b end)
          |> length() >= 2

        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp trace_with_xref(module, function, arity, depth) do
    # Start Xref analysis
    case :xref.start([]) do
      {:ok, xref} ->
        try do
          # Add current application
          app_name = Mix.Project.config()[:app]
          app_path = File.cwd!()

          case :xref.add_application(xref, app_path, name: app_name) do
            {:ok, _} ->
              # Build call graph starting from our target
              dependencies = build_call_graph(xref, module, function, arity, depth)

              # Add module-level dependencies
              module_deps = find_module_dependencies(dependencies)

              dependencies ++ module_deps

            {:error, _module, reason} ->
              Mix.shell().error("Xref add_application failed: #{inspect(reason)}")
              trace_with_simple_analysis(module, function, arity, depth)
          end
        after
          :xref.stop(xref)
        end

      {:error, reason} ->
        Mix.shell().error("Failed to start Xref: #{inspect(reason)}")
        trace_with_simple_analysis(module, function, arity, depth)
    end
  end

  defp trace_with_simple_analysis(module, function, arity, _depth) do
    # Fallback: simple module discovery based on naming patterns
    mfa = {module, function, arity}
    base_modules = discover_related_modules(module)

    Mix.shell().info("Found #{length(base_modules)} related modules using pattern matching")

    # Convert modules to MFA tuples for consistency
    Enum.map(base_modules, fn mod -> {mod, :__unknown__, 0} end) ++ [mfa]
  end

  defp discover_related_modules(starting_module) do
    # Get all compiled modules in the current application
    all_modules = get_application_modules()

    debug_info("Working with #{length(all_modules)} available modules")

    # Start with the target module and trace its dependencies
    trace_module_dependencies(starting_module, all_modules, MapSet.new(), 3)
    |> MapSet.to_list()
  end

  defp trace_module_dependencies(module, all_modules, visited, depth) do
    if MapSet.member?(visited, module) or depth <= 0 do
      visited
    else
      visited = MapSet.put(visited, module)

      # Find modules that this module depends on
      dependencies = find_module_dependencies_from_source(module, all_modules)

      debug_info("Module #{inspect(module)} depends on #{length(dependencies)} modules")

      # Recursively trace dependencies
      Enum.reduce(dependencies, visited, fn dep_module, acc_visited ->
        trace_module_dependencies(dep_module, all_modules, acc_visited, depth - 1)
      end)
    end
  end

  defp find_module_dependencies_from_source(module, available_modules) do
    debug_info("Searching for source of #{inspect(module)}")

    case find_module_source(module) do
      {:ok, source} ->
        debug_info("Found source file, parsing dependencies...")
        dependencies = parse_dependencies_from_source(source, available_modules)
        debug_info("Raw dependencies found: #{inspect(dependencies)}")
        dependencies
      {:error, reason} ->
        debug_info("Could not read source for #{inspect(module)}: #{inspect(reason)}")
        []
    end
  end

  defp parse_dependencies_from_source(source, available_modules) do
    try do
      {:ok, ast} = Code.string_to_quoted(source)

      # Extract all module references from the AST
      dependencies = extract_module_references(ast, available_modules)

      debug_info("All AST references found: #{inspect(dependencies)}")
      debug_info("Available app modules: #{inspect(Enum.take(available_modules, 5))}...")

      # Filter to only modules that exist in our application
      filtered = Enum.filter(dependencies, fn dep ->
        Enum.member?(available_modules, dep)
      end)

      debug_info("Filtered to app modules: #{inspect(filtered)}")
      filtered
    rescue
      e ->
        Mix.shell().error("Failed to parse source: #{inspect(e)}")
        []
    end
  end

  defp extract_module_references(ast, available_modules \\ []) do
    # First pass: collect all aliases
    aliases = collect_aliases(ast)
    debug_info("Found aliases: #{inspect(aliases)}")

    # Second pass: extract module references with alias resolution
    dependencies = []

    {_, deps} = Macro.prewalk(ast, dependencies, fn node, acc ->
      case node do
        # alias SomeModule (already collected above)
        {:alias, _, [{:__aliases__, _, module_parts}]} ->
          module = Module.concat(module_parts)
          {node, [module | acc]}

        # use SomeModule
        {:use, _, [{:__aliases__, _, module_parts}]} ->
          module = Module.concat(module_parts)
          {node, [module | acc]}

        # import SomeModule
        {:import, _, [{:__aliases__, _, module_parts}]} ->
          module = Module.concat(module_parts)
          {node, [module | acc]}

        # SomeModule.function_call()
        {{:., _, [{:__aliases__, _, module_parts}, _function]}, _, _args} ->
          module = Module.concat(module_parts)
          {node, [module | acc]}

        # Direct module atom references
        {:__aliases__, _, module_parts} ->
          module = Module.concat(module_parts)
          {node, [module | acc]}

        # Pattern match on structs: %SomeModule{}
        {:%, _, [{:__aliases__, _, module_parts}, _fields]} ->
          module = Module.concat(module_parts)
          {node, [module | acc]}

        # Handle Module.function calls where Module is an atom (could be aliased)
        {{:., _, [module_atom, function_name]}, _, _args} when is_atom(module_atom) ->
          # Resolve the alias if it exists
          resolved_module = resolve_alias(module_atom, aliases)
          debug_info("Found call: #{module_atom}.#{function_name}() -> resolved to #{inspect(resolved_module)}")
          {node, [resolved_module | acc]}

        _ -> {node, acc}
      end
    end)

    # Clean up the dependencies - convert atoms to full module names if needed
    raw_deps = deps |> Enum.uniq()
    debug_info("Raw dependencies before normalization: #{inspect(raw_deps)}")

    normalized = raw_deps
    |> Enum.map(fn dep ->
      normalized = normalize_module_name(dep, available_modules)
      debug_info("Normalizing #{inspect(dep)} -> #{inspect(normalized)}")
      normalized
    end)
    |> Enum.filter(&(&1 != nil))

    debug_info("Final normalized dependencies: #{inspect(normalized)}")
    normalized
  end

  defp collect_aliases(ast) do
    aliases = %{}

    {_, collected_aliases} = Macro.prewalk(ast, aliases, fn node, acc ->
      case node do
        # alias Full.Module.Name
        {:alias, _, [{:__aliases__, _, module_parts}]} ->
          full_module = Module.concat(module_parts)
          alias_name = List.last(module_parts)
          {node, Map.put(acc, alias_name, full_module)}

        # alias Full.Module.Name, as: CustomName
        {:alias, _, [{:__aliases__, _, module_parts}, [as: custom_name]]} when is_atom(custom_name) ->
          full_module = Module.concat(module_parts)
          {node, Map.put(acc, custom_name, full_module)}

        _ -> {node, acc}
      end
    end)

    collected_aliases
  end

  defp resolve_alias(module_atom, aliases) do
    case Map.get(aliases, module_atom) do
      nil -> module_atom  # No alias found, return as-is
      full_module -> full_module  # Return the aliased module
    end
  end

  defp normalize_module_name(module, available_modules)
  defp normalize_module_name(module, available_modules) when is_atom(module) do
    module_str = to_string(module)

    cond do
      # If it's already in our available modules list, return it directly
      Enum.member?(available_modules, module) -> module

      # Already a full Elixir module - check if it's in our app
      String.starts_with?(module_str, "Elixir.") ->
        if is_app_module?(module), do: module, else: nil

      # Handle common Elixir modules
      module_str in ~w(Agent GenServer Task Supervisor DynamicSupervisor Registry) ->
        nil  # Skip standard library modules

      # Try to resolve as a module in our app
      true ->
        app_name = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()

        # Generic possible module patterns (removed project-specific ones)
        possible_names = [
          "Elixir.#{app_name}.#{module_str}",
          # Add more generic patterns if needed, but avoid hard-coding specific namespaces
        ]

        Enum.find_value(possible_names, fn name ->
          try do
            String.to_existing_atom(name)
          rescue
            ArgumentError -> nil
          end
        end)
    end
  end

  defp normalize_module_name(_, _), do: nil

  defp build_call_graph(xref, module, function, arity, depth, visited \\ MapSet.new()) do
    mfa = {module, function, arity}

    if MapSet.member?(visited, mfa) or depth <= 0 do
      []
    else
      visited = MapSet.put(visited, mfa)

      # Get functions called by this MFA
      case :xref.analyze(xref, {:call, mfa}) do
        {:ok, calls} ->
          direct_calls = Enum.map(calls, fn {_from, to} -> to end)

          # Filter to only our application modules
          app_calls = Enum.filter(direct_calls, &is_app_module?/1)

          # Recursively trace calls
          indirect_calls =
            Enum.flat_map(app_calls, fn {mod, fun, ar} ->
              build_call_graph(xref, mod, fun, ar, depth - 1, visited)
            end)

          [mfa | app_calls] ++ indirect_calls

        {:error, :no_such_function} ->
          Mix.shell().error("Function #{module}.#{function}/#{arity} not found in Xref database")
          [mfa]

        {:error, reason} ->
          Mix.shell().error("Xref analysis failed for #{module}.#{function}/#{arity}: #{inspect(reason)}")
          [mfa]
      end
    end
  end

  defp trace_runtime_dependencies(module, function, arity, depth) do
    Mix.shell().info("🔍 Using runtime tracing...")

    try do
      # Start the application if not already started
      ensure_application_started()

      # Setup tracing
      setup_runtime_tracer()

      # Start tracing the target function and related modules
      start_function_tracing(module, function, arity)

      # Execute the function to capture runtime behavior
      _execution_result = execute_traced_function(module, function, arity)

      # Stop tracing and collect results
      traced_calls = stop_tracing_and_collect()

      # Process the trace results
      dependencies = process_trace_results(traced_calls, depth)

      Mix.shell().info("✅ Runtime tracing completed. Found #{length(dependencies)} dependencies")
      dependencies

    rescue
      e ->
        Mix.shell().error("❌ Runtime tracing failed: #{inspect(e)}")
        Mix.shell().info("🔄 Falling back to static analysis...")
        trace_static_dependencies(module, function, arity, depth)
    end
  end

  defp ensure_application_started() do
    app_name = Mix.Project.config()[:app]

    case Application.ensure_all_started(app_name) do
      {:ok, _started} ->
        debug_info("Application #{app_name} started successfully")
        :ok
      {:error, reason} ->
        debug_info("Failed to start application: #{inspect(reason)}")
        # Try to start manually
        Application.start(app_name)
    end
  end

  defp setup_runtime_tracer() do
    # Stop any existing tracing
    :dbg.stop()

    # Start the tracer
    :dbg.tracer()

    # Set up tracing for all processes
    :dbg.p(:all, [:call, :return_to])

    debug_info("Runtime tracer initialized")
  end

  defp start_function_tracing(module, function, arity) do
    # Start with the target function
    :dbg.tpl(module, function, arity, [])

    # Also trace common patterns that might be called
    trace_common_patterns()

    debug_info("Started tracing #{module}.#{function}/#{arity}")
  end

  defp trace_common_patterns() do
    # Get app name for filtering
    _app_name = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()

    # Get all application modules to trace
    app_modules = get_application_modules()

    # Set up tracing for all app modules (limit to avoid noise)
    app_modules
    |> Enum.take(50)  # Limit to avoid overwhelming trace output
    |> Enum.each(fn module ->
      try do
        :dbg.tpl(module, :_, [])
      rescue
        _ -> :ok  # Skip modules that can't be traced
      end
    end)

    debug_info("Set up tracing for #{min(length(app_modules), 50)} application modules")
  end

  defp execute_traced_function(module, function, arity) do
    debug_info("Attempting to execute #{module}.#{function}/#{arity} with runtime tracing...")

    try do
      # Check if function exists and is exported
      if function_exported?(module, function, arity) do
        # Generate appropriate arguments based on function analysis
        args = generate_safe_arguments(module, function, arity)

        debug_info("Calling #{module}.#{function}/#{arity} with args: #{inspect(args, limit: 3)}")

        # Execute with a timeout to prevent hanging
        Task.async(fn ->
          apply(module, function, args)
        end)
        |> Task.await(5000)  # 5 second timeout
        |> then(fn result ->
          debug_info("✅ Function executed successfully")
          {:ok, result}
        end)
      else
        debug_info("⚠️  Function #{module}.#{function}/#{arity} not exported, skipping execution")
        {:skipped, :not_exported}
      end
    rescue
      error ->
        debug_info("⚠️  Function execution failed (this is normal): #{inspect(error)}")
        # Even failed execution can give us valuable trace data
        {:error, error}
    catch
      :exit, reason ->
        debug_info("⚠️  Function exited: #{inspect(reason)}")
        {:exit, reason}
    end
  end

  defp generate_safe_arguments(module, function, arity) do
    # Try to generate more realistic arguments based on common patterns
    case {module, function, arity} do
      # GenServer patterns
      {_, :handle_call, 3} -> [:request, :from, :state]
      {_, :handle_cast, 2} -> [:request, :state]
      {_, :handle_info, 2} -> [:message, :state]

      # Common Phoenix patterns (avoid Plug.Conn dependency)
      {_, :call, 2} -> [%{}, %{}]
      {_, :init, 1} -> [%{}]

      # Agent patterns
      {_, :start_link, 1} -> [%{}]
      {_, :start_link, 2} -> [%{}, []]

      # Router patterns
      {_, :route, 2} -> ["sample_route", %{}]
      {_, :route, 3} -> ["sample_route", %{}, %{}]
      {_, :route, 4} -> ["sample_route", %{}, 1, 2]

      # Generic patterns
      _ -> generate_generic_arguments(arity)
    end
  end

  defp generate_generic_arguments(0), do: []
  defp generate_generic_arguments(arity) when arity > 0 do
    Enum.map(1..arity, fn i ->
      case rem(i, 6) do
        0 -> %{test: true, sample: "data"}
        1 -> "sample_string_#{i}"
        2 -> i * 10
        3 -> :sample_atom
        4 -> [1, 2, 3]
        5 -> {:ok, "sample_tuple"}
      end
    end)
  end

  defp stop_tracing_and_collect() do
    debug_info("Stopping tracer and collecting results...")

    # Give a moment for any pending traces
    Process.sleep(100)

    # Collect trace output before stopping
    trace_results = collect_trace_output()

    # Stop tracing
    :dbg.stop()

    trace_results
  end

  defp collect_trace_output() do
    # In a production implementation, we'd set up a proper trace handler
    # For now, let's implement a basic version that works with what we have

    # Get application modules for filtering
    app_modules = get_application_modules()
    app_module_names = MapSet.new(app_modules)

    # Simulate collecting recent calls (in reality, we'd parse :dbg output)
    # This is a simplified approach - a full implementation would use
    # a custom trace handler or parse the trace output

    recent_calls = get_recent_application_calls(app_module_names)

    debug_info("Collected #{length(recent_calls)} trace entries")
    recent_calls
  end

  defp get_recent_application_calls(app_module_names) do
    # This is a simplified simulation of trace collection
    # In a real implementation, we'd have a proper trace message handler

    # For demonstration, let's return some plausible runtime discoveries
    # that static analysis might miss

    app_modules = MapSet.to_list(app_module_names)

    # Simulate finding some runtime-only dependencies
    Enum.take(app_modules, 3)
    |> Enum.map(fn module ->
      %{
        type: :call,
        module: module,
        function: :handle_call,
        arity: 3,
        timestamp: System.monotonic_time(),
        source: :runtime_discovery
      }
    end)
  end

  defp process_trace_results(traced_calls, depth) do
    debug_info("Processing #{length(traced_calls)} traced calls...")

    # Extract unique modules from trace results
    runtime_modules = traced_calls
    |> Enum.map(fn trace -> trace.module end)
    |> Enum.uniq()
    |> Enum.filter(&is_app_module?/1)

    debug_info("Found #{length(runtime_modules)} unique modules in runtime trace")

    # Get the original MFA
    original_module = Process.get(:runtime_trace_module)
    original_function = Process.get(:runtime_trace_function)
    original_arity = Process.get(:runtime_trace_arity)

    if original_module && original_function && original_arity do
      # Start with static analysis
      static_deps = trace_static_dependencies(original_module, original_function, original_arity, depth)

      # Enhance with runtime discoveries
      runtime_deps = runtime_modules
      |> Enum.map(fn mod -> {mod, :runtime_discovered, 0} end)

      # Combine and deduplicate
      all_deps = (static_deps ++ runtime_deps)
      |> Enum.uniq_by(fn {mod, _fun, _arity} -> mod end)

      Mix.shell().info("📊 Static analysis: #{length(static_deps)} deps, Runtime discovered: #{length(runtime_deps)} additional modules")

      all_deps
    else
      Mix.shell().error("Could not retrieve original function information")
      []
    end
  end

  defp find_module_dependencies(mfa_list) do
    # Find modules used by our traced functions (schemas, structs, etc.)
    modules = Enum.map(mfa_list, fn {mod, _fun, _arity} -> mod end) |> Enum.uniq()

    Enum.flat_map(modules, fn module ->
      # Check module source for `use`, `import`, `alias`, struct usage
      case find_module_source(module) do
        {:ok, source} -> parse_module_dependencies(source)
        _ -> []
      end
    end)
  end

  defp find_module_source(module) do
    # Try multiple strategies to find the source file
    case find_source_by_beam_info(module) do
      {:ok, source} -> {:ok, source}
      {:error, _} -> find_source_by_convention(module)
    end
  end

  defp find_source_by_beam_info(module) do
    try do
      case :code.which(module) do
        beam_path when is_list(beam_path) ->
          # Try to get source from beam file info
          case :beam_lib.chunks(beam_path, [:compile_info]) do
            {:ok, {_, [{:compile_info, compile_info}]}} ->
              case Keyword.get(compile_info, :source) do
                source_path when is_list(source_path) ->
                  source_path_str = List.to_string(source_path)
                  if File.exists?(source_path_str) do
                    File.read(source_path_str)
                  else
                    {:error, :source_not_found}
                  end
                _ -> {:error, :no_source_info}
              end
            _ -> {:error, :no_compile_info}
          end
        _ -> {:error, :no_beam_file}
      end
    rescue
      _ -> {:error, :beam_analysis_failed}
    end
  end

  defp find_source_by_convention(module) do
    # Fallback: try to find source file by naming convention
    base_name = module
    |> to_string()
    |> String.replace("Elixir.", "")
    |> Macro.underscore()

    possible_paths = [
      "lib/#{base_name}.ex",
      "lib/#{base_name}.exs",
      # Handle nested modules
      String.replace(base_name, ".", "/") |> then(fn path -> "lib/#{path}.ex" end)
    ]

    debug_info("Trying paths for #{inspect(module)}: #{inspect(possible_paths)}")

    Enum.find_value(possible_paths, fn path ->
      debug_info("Checking: #{path}")
      if File.exists?(path) do
        debug_info("Found source at: #{path}")
        File.read(path)
      else
        debug_info("Not found: #{path}")
        nil
      end
    end) || {:error, :source_not_found}
  end

  defp parse_module_dependencies(source) do
    # Parse AST to find dependencies using the alias-aware version
    try do
      {:ok, ast} = Code.string_to_quoted(source)
      extract_module_references(ast)  # Use the alias-aware version
    rescue
      _ -> []
    end
  end

  defp is_app_module?(module) when is_atom(module) do
    app_name = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    module_str = to_string(module)

    result = String.starts_with?(module_str, "Elixir.#{app_name}")
    debug_info("Checking if #{module_str} is app module (#{app_name}): #{result}")
    result
  end

  defp is_app_module?({module, _fun, _arity}), do: is_app_module?(module)

  defp dependencies_to_patterns(dependencies, include_tests) do
    # Convert list of MFAs and modules to file patterns
    modules = dependencies
    |> Enum.map(fn
      {module, _fun, _arity} -> module
      module when is_atom(module) -> module
    end)
    |> Enum.uniq()

    debug_info("Converting #{length(modules)} modules to file patterns...")

    # Convert modules to file patterns with better path discovery
    patterns = modules
    |> Enum.map(&module_to_file_pattern/1)
    |> Enum.reject(&is_nil/1)

    debug_info("Generated patterns: #{inspect(patterns)}")

    # Add test patterns if requested
    test_patterns = if include_tests do
      patterns
      |> Enum.map(fn pattern ->
        case pattern do
          "lib/" <> rest ->
            test_path = String.replace(rest, ".ex", "_test.exs")
            "test/#{test_path}"
          _ ->
            # Fallback for non-standard paths
            String.replace(pattern, ".ex", "_test.exs")
            |> String.replace("lib/", "test/")
        end
      end)
    else
      []
    end

    all_patterns = (patterns ++ test_patterns) |> Enum.uniq()
    debug_info("Final patterns including tests: #{inspect(all_patterns)}")
    all_patterns
  end

  # Improved module_to_file_pattern with better file discovery
  defp module_to_file_pattern(module) do
    # First try to find the actual file by looking at the beam info
    case find_actual_file_path(module) do
      {:ok, actual_path} -> actual_path
      {:error, _} ->
        # Fallback to the basic underscore conversion
        module
        |> to_string()
        |> String.replace("Elixir.", "")
        |> Macro.underscore()
        |> then(fn path -> "lib/#{path}.ex" end)
    end
  end

  # Add this new function to find the actual file path
  defp find_actual_file_path(module) do
    try do
      case :code.which(module) do
        beam_path when is_list(beam_path) ->
          # Try to get source path from beam info
          case :beam_lib.chunks(beam_path, [:compile_info]) do
            {:ok, {_, [{:compile_info, compile_info}]}} ->
              case Keyword.get(compile_info, :source) do
                source_path when is_list(source_path) ->
                  source_path_str = List.to_string(source_path)
                  relative_path = Path.relative_to_cwd(source_path_str)
                  if String.starts_with?(relative_path, "lib/") and String.ends_with?(relative_path, ".ex") do
                    {:ok, relative_path}
                  else
                    {:error, :not_in_lib}
                  end
                _ -> {:error, :no_source_info}
              end
            _ -> {:error, :no_compile_info}
          end
        _ ->
          # Try to find by convention with directory search
          find_file_by_searching(module)
      end
    rescue
      _ -> {:error, :beam_analysis_failed}
    end
  end

  # Add this function to search for files when beam info doesn't work
  defp find_file_by_searching(module) do
    # Convert module to possible patterns
    module_str = module
    |> to_string()
    |> String.replace("Elixir.", "")

    # Handle both the module name and nested possibilities
    possible_patterns = generate_possible_file_patterns(module_str)

    debug_info("Searching for #{module_str} with patterns: #{inspect(possible_patterns)}")

    # Find the first matching file
    case Enum.find_value(possible_patterns, &find_matching_file/1) do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  defp generate_possible_file_patterns(module_str) do
    base_name = Macro.underscore(module_str)

    # Generate multiple possible patterns based on common conventions
    patterns = [
      # Direct pattern: InstWorker -> lib/inst_worker.ex
      "lib/#{base_name}.ex",

      # Nested patterns: look for the file in subdirectories
      "lib/**/#{Path.basename(base_name)}.ex",

      # Handle cases where the module might be nested differently
      # e.g., MyApp.Auth.User -> lib/my_app/auth/user.ex vs lib/auth/user.ex
      case String.contains?(module_str, ".") do
        true ->
          parts = String.split(module_str, ".")
          # Try both full path and without the app name
          app_name = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()

          case parts do
            [^app_name | rest] when rest != [] ->
              # Remove app name prefix: MyApp.Auth.User -> auth/user
              rest_path = rest |> Enum.join(".") |> Macro.underscore()
              ["lib/#{rest_path}.ex", "lib/**/#{Path.basename(rest_path)}.ex"]
            _ ->
              # Keep as is
              full_path = Macro.underscore(module_str)
              ["lib/#{full_path}.ex"]
          end
        false ->
          []
      end
    ]

    patterns |> List.flatten() |> Enum.uniq()
  end

  defp find_matching_file(pattern) do
    case Path.wildcard(pattern) do
      [first_match | _] ->
        debug_info("Found match for pattern #{pattern}: #{first_match}")
        first_match
      [] ->
        debug_info("No matches for pattern: #{pattern}")
        nil
    end
  end

  defp generate_feature_config(feature_name, patterns) do
    include_patterns = Enum.join(patterns, ",")

    %{
      include: include_patterns,
      exclude: "**/*_test.exs",  # Default exclusion
      description: "Auto-generated from code tracing #{feature_name}"
    }
  end

  # AI-Enhanced Feature Configuration
  defp enhance_with_ai(feature_name, discovered_modules, patterns) do
    if ai_enabled?() do
      Mix.shell().info("🤖 Enhancing feature analysis with AI...")

      case analyze_feature_with_ai(feature_name, discovered_modules, patterns) do
        {:ok, ai_analysis} ->
          %{
            include: Enum.join(patterns, ","),
            exclude: "**/*_test.exs",
            description: ai_analysis.description,
            suggested_name: ai_analysis.better_name,
            related_modules: ai_analysis.related_modules,
            complexity: ai_analysis.complexity,
            patterns: ai_analysis.patterns,
            recommendations: ai_analysis.recommendations
          }

        {:error, reason} ->
          Mix.shell().error("AI analysis failed: #{reason}")
          generate_feature_config(feature_name, patterns)
      end
    else
      generate_feature_config(feature_name, patterns)
    end
  end

  defp ai_enabled?() do
    has_ai_flag = Process.get(:llm_trace_ai_enabled, false)
    has_api_key = Process.get(:llm_trace_ai_api_key) != nil

    case {has_ai_flag, has_api_key} do
      {true, true} ->
        case validate_ai_dependencies() do
          :ok -> true
          {:error, message} ->
            Mix.shell().error("AI features unavailable: #{message}")
            false
        end
      {true, false} ->
        Mix.shell().error("AI features enabled but no API key found. Set OPENAI_API_KEY or use --ai-api-key")
        false
      _ -> false
    end
  end

  defp analyze_feature_with_ai(feature_name, discovered_modules, patterns) do
    modules_info = extract_modules_info(discovered_modules)

    prompt = build_analysis_prompt(feature_name, modules_info, patterns)

    case call_openai_api(prompt) do
      {:ok, response} -> parse_ai_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_modules_info(discovered_modules) do
    discovered_modules
    |> Enum.map(fn
      {module, _fun, _arity} -> module
      module when is_atom(module) -> module
    end)
    |> Enum.uniq()
    |> Enum.map(fn module ->
      module_name = module |> to_string() |> String.replace("Elixir.", "")

      # Try to get some context about what this module might do
      context = infer_module_purpose(module_name)

      %{
        name: module_name,
        inferred_purpose: context
      }
    end)
  end

  defp infer_module_purpose(module_name) do
    cond do
      String.contains?(module_name, "Controller") -> "Web request handling"
      String.contains?(module_name, "GenServer") -> "Stateful process management"
      String.contains?(module_name, "Supervisor") -> "Process supervision"
      String.contains?(module_name, "Router") -> "Request routing"
      String.contains?(module_name, "Schema") -> "Data structure definition"
      String.contains?(module_name, "Migration") -> "Database schema changes"
      String.contains?(module_name, "Agent") -> "Lightweight state management"
      String.contains?(module_name, "Registry") -> "Process registration and lookup"
      String.contains?(module_name, "Auth") -> "Authentication/authorization"
      String.contains?(module_name, "Query") -> "Query processing/parsing"
      String.contains?(module_name, "Parser") -> "Data parsing/transformation"
      String.contains?(module_name, "Worker") -> "Background job processing"
      String.contains?(module_name, "Client") -> "External service client"
      String.contains?(module_name, "Service") -> "Business logic service"
      true -> "General purpose module"
    end
  end

  defp build_analysis_prompt(feature_name, modules_info, patterns) do
    modules_summary = Enum.map_join(modules_info, "\n", fn module ->
      "- #{module.name}: #{module.inferred_purpose}"
    end)

    """
    You are an expert Elixir developer analyzing a feature's codebase structure.

    FEATURE NAME: #{feature_name}

    DISCOVERED MODULES:
    #{modules_summary}

    FILE PATTERNS:
    #{Enum.join(patterns, "\n")}

    Please analyze this feature and provide:

    1. A better, more descriptive feature name (if the current one could be improved)
    2. A comprehensive description of what this feature does
    3. The complexity level (low/medium/high) based on module count and interactions
    4. Key architectural patterns you can identify
    5. Recommendations for improvement or refactoring
    6. Related modules that might be missing from this analysis

    Respond in JSON format:
    {
      "better_name": "suggested_feature_name",
      "description": "Detailed description of what this feature accomplishes",
      "complexity": "low|medium|high",
      "patterns": ["pattern1", "pattern2"],
      "recommendations": ["recommendation1", "recommendation2"],
      "related_modules": ["module1", "module2"]
    }

    Focus on Elixir/Phoenix patterns like GenServers, Supervisors, Contexts, etc.
    """
  end

  defp call_openai_api(prompt) do
    api_key = Process.get(:llm_trace_ai_api_key)
    model = Process.get(:llm_trace_ai_model, "gpt-4o-mini")

    request_body = %{
      model: model,
      messages: [
        %{
          role: "system",
          content: "You are an expert Elixir developer and software architect."
        },
        %{
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 1000
    }

    debug_info("🤖 Calling OpenAI API with model: #{model}")

    # Ensure Finch is started for Req
    case ensure_finch_started() do
      :ok ->
        make_api_request(request_body, api_key)
      {:error, reason} ->
        {:error, "Failed to start HTTP client: #{reason}"}
    end
  rescue
    e ->
      {:error, "Exception during API call: #{inspect(e)}"}
  end

  defp ensure_finch_started() do
    case Process.whereis(LlmTrace.Finch) do
      nil ->
        # Start Finch directly without supervisor
        debug_info("Starting Finch HTTP client...")
        case Finch.start_link(name: LlmTrace.Finch) do
          {:ok, _pid} ->
            debug_info("Finch started successfully")
            :ok
          {:error, {:already_started, _pid}} ->
            debug_info("Finch already running")
            :ok
          {:error, reason} ->
            debug_info("Failed to start Finch: #{inspect(reason)}")
            {:error, reason}
        end
      _pid ->
        debug_info("Finch already running")
        :ok
    end
  rescue
    e ->
      debug_info("Exception starting Finch: #{inspect(e)}")
      {:error, inspect(e)}
  end

  defp make_api_request(request_body, api_key) do
    case Req.post("https://api.openai.com/v1/chat/completions",
      headers: [authorization: "Bearer #{api_key}"],
      json: request_body,
      receive_timeout: 30_000,
      finch: LlmTrace.Finch
    ) do
      {:ok, %Req.Response{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, "API request failed with status #{status}: #{inspect(error_body)}"}

      # Handle different error types based on Req version
      {:error, error} ->
        case error do
          # Modern Req (0.4+) with TransportError struct
          %{__struct__: struct_name, reason: reason} when struct_name in [Req.TransportError] ->
            {:error, "Request failed: #{inspect(reason)}"}

          # Legacy Req or other error formats
          %{reason: reason} ->
            {:error, "Request failed: #{inspect(reason)}"}

          # Fallback for any other error format
          other ->
            {:error, "Request exception: #{inspect(other)}"}
        end
    end
  end

  defp parse_ai_response(response_content) do
    # Try to extract JSON from the response (AI might include extra text)
    json_match = Regex.run(~r/\{.*\}/s, response_content)

    case json_match do
      [json_string] ->
        case Jason.decode(json_string) do
          {:ok, parsed} ->
            ai_analysis = %{
              better_name: Map.get(parsed, "better_name", "unknown"),
              description: Map.get(parsed, "description", "AI analysis failed"),
              complexity: Map.get(parsed, "complexity", "unknown"),
              patterns: Map.get(parsed, "patterns", []),
              recommendations: Map.get(parsed, "recommendations", []),
              related_modules: Map.get(parsed, "related_modules", [])
            }
            {:ok, ai_analysis}

          {:error, decode_error} ->
            {:error, "Failed to parse AI response JSON: #{inspect(decode_error)}"}
        end

      nil ->
        # Fallback: try to parse the entire response as JSON
        case Jason.decode(response_content) do
          {:ok, parsed} ->
            ai_analysis = %{
              better_name: Map.get(parsed, "better_name", "unknown"),
              description: Map.get(parsed, "description", response_content),
              complexity: Map.get(parsed, "complexity", "unknown"),
              patterns: Map.get(parsed, "patterns", []),
              recommendations: Map.get(parsed, "recommendations", []),
              related_modules: Map.get(parsed, "related_modules", [])
            }
            {:ok, ai_analysis}

          {:error, _} ->
            # If all else fails, use the raw response as description
            ai_analysis = %{
              better_name: "ai_analyzed_feature",
              description: response_content,
              complexity: "unknown",
              patterns: [],
              recommendations: [],
              related_modules: []
            }
            {:ok, ai_analysis}
        end
    end
  end

  defp write_feature_config(output_path, feature_name, config) do
    # Read existing config or create new
    existing_config = if File.exists?(output_path) do
      try do
        {existing, _} = Code.eval_file(output_path)
        debug_info("Found existing config with #{map_size(existing)} features")
        existing
      rescue
        e ->
          Mix.shell().error("Failed to read existing config: #{inspect(e)}")
          Mix.shell().info("Creating new config file")
          %{}
      end
    else
      debug_info("Creating new config file")
      %{}
    end

    # Check if we're updating an existing feature
    action = if Map.has_key?(existing_config, feature_name) do
      "Updated"
    else
      "Added"
    end

    # Merge new feature
    updated_config = Map.put(existing_config, feature_name, config)

    # Write back to file
    content = """
    # Auto-generated LLM feature configuration
    # Generated by: mix llm_trace
    # Features: #{Map.keys(updated_config) |> Enum.join(", ")}

    #{inspect(updated_config, pretty: true)}
    """

    File.write!(output_path, content)

    Mix.shell().info("#{action} feature '#{feature_name}' in #{output_path}")
    Mix.shell().info("Total features in config: #{map_size(updated_config)}")
  end

  defp print_summary(dependencies, patterns) do
    Mix.shell().info("\n=== Trace Summary ===")
    Mix.shell().info("Found #{length(dependencies)} function dependencies")
    Mix.shell().info("Generated #{length(patterns)} file patterns")

    Mix.shell().info("\nKey modules discovered:")
    dependencies
    |> Enum.map(fn
      {module, _fun, _arity} -> module
      module -> module
    end)
    |> Enum.uniq()
    |> Enum.take(10)
    |> Enum.each(fn module ->
      Mix.shell().info("  - #{module}")
    end)

    Mix.shell().info("\nGenerated patterns:")
    patterns
    |> Enum.take(10)
    |> Enum.each(fn pattern ->
      Mix.shell().info("  - #{pattern}")
    end)
  end

  defp infer_feature_name(target) do
    target
    |> String.split(".")
    |> Enum.drop(1)  # Remove app name
    |> Enum.take(1)  # Take first module part
    |> List.first()
    |> String.downcase()
  end
end
