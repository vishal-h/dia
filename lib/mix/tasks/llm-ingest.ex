defmodule Mix.Tasks.LlmIngest do
  use Mix.Task

  @default_excludes [
    # Version control
    ".git/",
    # Build artifacts
    "_build/", "deps/", "node_modules/", "*.beam", "*.o", "*.so", "*.dylib", "*.a",
    # Dependency files
    "mix.lock", "package-lock.json", "yarn.lock", "Gemfile.lock",
    # System files
    ".DS_Store", "Thumbs.db",
    # Editor files
    "*.swp", "*.swo", "*.swn", ".idea/", ".vscode/",
    # Elixir specific
    "erl_crash.dump", "*.ez",
    # Documentation output (to avoid including generated llm-ingest files)
    "doc/llm-ingest*.md"
  ]
  @separator "\n---\n"
  @line_ending "\n"

  @impl true
  def run(args) do
    {opts, args, _} = OptionParser.parse(args,
      switches: [
        exclude: :string,
        include: :string,
        output: :string,
        "no-gitignore": :boolean,
        feature: :string
      ]
    )

    root = Path.expand(List.first(args) || ".")

    # Load feature configuration if specified
    {feature_include, feature_exclude} = load_feature_config(opts[:feature], root)

    exclude_patterns = parse_patterns(opts[:exclude]) || []
    include_patterns = parse_patterns(opts[:include]) || feature_include

    # Generate output filename based on feature
    default_filename = case opts[:feature] do
      nil -> "llm-ingest.md"
      feature -> "llm-ingest-#{feature}.md"
    end

    output_file = opts[:output] || default_filename

    # Ensure doc directory exists and prepend it unless output already includes a path
    output_file = case Path.dirname(output_file) do
      "." -> Path.join("doc", output_file)
      _ -> output_file
    end

    # Create doc directory if it doesn't exist
    File.mkdir_p!(Path.dirname(output_file))

    use_gitignore = !opts[:"no-gitignore"]

    gitignore_patterns = if use_gitignore, do: read_gitignore_patterns(root), else: []
    all_excludes = Enum.uniq(@default_excludes ++ exclude_patterns ++ feature_exclude ++ gitignore_patterns)

    project_name = case Mix.Project.config()[:app] do
      nil -> Path.basename(root)
      app -> to_string(app)
    end
    description = Mix.Project.config()[:description] || "No description"

    File.write!(output_file, "", [:raw])
    write_section(output_file, "# #{project_name}\n#{description}")

    # Add feature section if a feature was specified
    if opts[:feature] do
      feature_section = generate_feature_section(opts[:feature], feature_include, feature_exclude)
      write_section(output_file, feature_section)
    end

    # Add notes section for LLM guidance
    notes_section = generate_notes_section(opts[:feature], include_patterns)
    if notes_section do
      write_section(output_file, notes_section)
    end

    # Add folder structure section with markdown header
    write_section(output_file, "## Project Structure\n\n```\n#{generate_folder_structure(root, all_excludes, include_patterns)}```")

    # Add files section header
    write_section(output_file, "## Files")

    write_files_content(output_file, root, all_excludes, include_patterns)

    Mix.shell().info("Generated #{output_file}")
  end

  defp generate_feature_section(feature_name, feature_include, feature_exclude) do
    case feature_include do
      nil ->
        "## Feature: #{feature_name}\n\nFeature configuration not found or invalid."
      patterns when is_list(patterns) ->
        build_enhanced_feature_section(feature_name, patterns, feature_exclude)
      include_string when is_binary(include_string) ->
        patterns = String.split(include_string, ",") |> Enum.map(&String.trim/1)
        build_enhanced_feature_section(feature_name, patterns, feature_exclude)
    end
  end

  defp build_enhanced_feature_section(feature_name, patterns, exclude_patterns) do
    # Try to get enhanced feature config from llm_features_traced.exs or similar
    enhanced_config = get_enhanced_feature_config(feature_name)

    case enhanced_config do
      %{description: ai_description} when ai_description != nil ->
        build_ai_enhanced_section(feature_name, patterns, exclude_patterns, enhanced_config)

      _ ->
        build_basic_feature_section(feature_name, patterns, exclude_patterns)
    end
  end

  defp build_ai_enhanced_section(feature_name, patterns, exclude_patterns, config) do
    header = "## Feature: #{feature_name}"

    # Use AI-suggested name if available
    header = case Map.get(config, :suggested_name) do
      nil -> header
      suggested when is_binary(suggested) ->
        "## Feature: #{feature_name} (AI Suggests: #{suggested})"
      _ -> header
    end

    description_section = case Map.get(config, :description) do
      nil -> ""
      desc -> "\n### Description\n#{desc}\n"
    end

    metadata_section = build_metadata_section(config)

    patterns_section = build_patterns_section(patterns, exclude_patterns)

    recommendations_section = build_recommendations_section(config)

    "#{header}#{description_section}#{metadata_section}#{patterns_section}#{recommendations_section}"
  end

  defp build_metadata_section(config) do
    metadata_items = []

    metadata_items = case Map.get(config, :complexity) do
      nil -> metadata_items
      complexity -> ["**Complexity:** #{String.capitalize(complexity)}" | metadata_items]
    end

    metadata_items = case Map.get(config, :patterns) do
      nil -> metadata_items
      [] -> metadata_items
      patterns when is_list(patterns) ->
        ["**Architecture Patterns:** #{Enum.join(patterns, ", ")}" | metadata_items]
      _ -> metadata_items
    end

    metadata_items = case Map.get(config, :related_modules) do
      nil -> metadata_items
      [] -> metadata_items
      modules when is_list(modules) ->
        ["**Related Modules:** #{Enum.join(modules, ", ")}" | metadata_items]
      _ -> metadata_items
    end

    case metadata_items do
      [] -> ""
      items ->
        "\n### Feature Metadata\n" <>
        Enum.map_join(Enum.reverse(items), "\n", fn item -> "#{item}" end) <> "\n"
    end
  end

  defp build_recommendations_section(config) do
    case Map.get(config, :recommendations) do
      nil -> ""
      [] -> ""
      recommendations when is_list(recommendations) ->
        formatted_recommendations = Enum.with_index(recommendations, 1)
        |> Enum.map_join("\n", fn {rec, index} -> "#{index}. #{rec}" end)

        "\n### AI Recommendations\n#{formatted_recommendations}\n"
      _ -> ""
    end
  end

  defp build_patterns_section(patterns, exclude_patterns) do
    include_text = "**Include patterns:** `#{Enum.join(patterns, "`, `")}`\n"
    exclude_text = case exclude_patterns do
      [] -> ""
      nil -> ""
      excludes when is_list(excludes) -> "**Exclude patterns:** `#{Enum.join(excludes, "`, `")}`\n"
      exclude_string when is_binary(exclude_string) -> "**Exclude patterns:** `#{exclude_string}`\n"
      _ -> ""
    end

    "\n### File Patterns\n#{include_text}#{exclude_text}"
  end

  defp build_basic_feature_section(feature_name, patterns, exclude_patterns) do
    header = "## Feature: #{feature_name}\n"
    patterns_section = build_patterns_section(patterns, exclude_patterns)
    "#{header}#{patterns_section}"
  end

  defp get_enhanced_feature_config(feature_name) do
    # Try multiple sources for enhanced config
    enhanced_files = [
      "llm_features_traced.exs",
      "llm_features_enhanced.exs",
      "llm_features.exs"
    ]

    Enum.find_value(enhanced_files, fn file ->
      if File.exists?(file) do
        try do
          {config, _} = Code.eval_file(file)
          case Map.get(config, feature_name) do
            nil -> nil
            feature_config when is_map(feature_config) ->
              # Convert string keys to atoms for easier access
              feature_config
              |> Enum.map(fn {k, v} -> {ensure_atom(k), v} end)
              |> Enum.into(%{})
            _ -> nil
          end
        rescue
          _ -> nil
        end
      else
        nil
      end
    end)
  end

  defp ensure_atom(key) when is_atom(key), do: key
  defp ensure_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> String.to_atom(key)
    end
  end
  defp ensure_atom(key), do: key

  defp load_feature_config(nil, _root), do: {nil, []}
  defp load_feature_config(feature_name, root) do
    # Try multiple config files in order of preference
    config_files = [
      "llm_features_traced.exs",  # AI-generated features (try first)
      "llm_features.exs",         # Manual features
      "llm_features_enhanced.exs" # Alternative naming
    ]

    Enum.find_value(config_files, fn config_file ->
      config_path = Path.join(root, config_file)

      if File.exists?(config_path) do
        try do
          {features_config, _} = Code.eval_file(config_path)

          case Map.get(features_config, feature_name) do
            nil ->
              debug_info("Feature '#{feature_name}' not found in #{config_file}")
              nil

            feature_config ->
              Mix.shell().info("Found feature '#{feature_name}' in #{config_file}")
              include_patterns = parse_patterns(feature_config[:include])
              exclude_patterns = parse_patterns(feature_config[:exclude]) || []
              {:found, {include_patterns, exclude_patterns}}
          end
        rescue
          e ->
            Mix.shell().error("Failed to load #{config_file}: #{inspect(e)}")
            nil
        end
      else
        debug_info("Config file #{config_file} not found")
        nil
      end
    end)
    |> case do
      {:found, result} -> result
      nil -> handle_feature_not_found(feature_name, config_files)
    end
  end

  defp handle_feature_not_found(feature_name, checked_files) do
    Mix.shell().error("Feature '#{feature_name}' not found in any config file")

    # Show which files were checked
    Mix.shell().info("Checked files: #{Enum.join(checked_files, ", ")}")

    # Try to show available features from all files
    available_features = get_all_available_features(checked_files)

    if length(available_features) > 0 do
      Mix.shell().info("Available features: #{Enum.join(available_features, ", ")}")
    else
      Mix.shell().info("No feature configuration files found")
      print_example_config()
    end

    {nil, []}
  end

  defp get_all_available_features(config_files) do
    config_files
    |> Enum.flat_map(fn file ->
      if File.exists?(file) do
        try do
          {config, _} = Code.eval_file(file)
          Map.keys(config)
        rescue
          _ -> []
        end
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  # Helper function for conditional debug output
  defp debug_info(message) do
    # For now, always show these info messages since they're helpful
    # You could make this conditional based on a --verbose flag if needed
    Mix.shell().info(message)
  end

  defp print_example_config do
    example = """

    Example llm_features.exs:
    %{
      "auth" => %{
        include: "lib/auth/**,test/auth/**,priv/repo/migrations/*_auth_*",
        exclude: "**/*_test.exs"
      },
      "api" => %{
        include: "lib/api/**,lib/schemas/**,test/api/**"
      },
      "frontend" => %{
        include: "assets/**,lib/*_web/**,test/*_web/**"
      }
    }
    """
    Mix.shell().info(example)
  end

  defp read_gitignore_patterns(root) do
    gitignore_path = Path.join(root, ".gitignore")

    if File.exists?(gitignore_path) do
      gitignore_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn line ->
        String.starts_with?(line, "#") || line == ""
      end)
    else
      []
    end
  end

  defp parse_patterns(nil), do: nil
  defp parse_patterns(str), do: String.split(str, ",") |> Enum.map(&String.trim/1)

  defp write_section(output_file, content) do
    File.write!(output_file, [content, @separator], [:append, :raw])
  end

  defp generate_folder_structure(root, exclude_patterns, include_patterns) do
    relative_root = Path.relative_to_cwd(root)
    "#{relative_root}/#{@line_ending}" <> build_tree(root, exclude_patterns, include_patterns, "", true)
  end

  defp build_tree(path, exclude_patterns, include_patterns, prefix, is_root) do
    if File.dir?(path) do
      children =
        path
        |> File.ls!()
        |> Enum.reject(&should_exclude?(&1, path, exclude_patterns))
        |> Enum.filter(&should_include?(&1, path, include_patterns))
        |> Enum.sort()

      children
      |> Enum.with_index()
      |> Enum.map_join("", fn {child, index} ->
        is_last = index == length(children) - 1
        full_path = Path.join(path, child)

        current_prefix = if is_root, do: "", else: prefix
        connector = if is_last, do: "└── ", else: "├── "
        next_prefix = if is_last, do: "    ", else: "│   "

        if File.dir?(full_path) do
          "#{current_prefix}#{connector}#{child}/#{@line_ending}" <>
          build_tree(full_path, exclude_patterns, include_patterns, current_prefix <> next_prefix, false)
        else
          "#{current_prefix}#{connector}#{child}#{@line_ending}"
        end
      end)
    else
      ""
    end
  end

  defp should_exclude?(item, current_path, exclude_patterns) do
    full_path = Path.join(current_path, item)
    relative_path = Path.relative_to_cwd(full_path)

    matches_any_pattern?(item, exclude_patterns) ||
    matches_any_pattern?(relative_path, exclude_patterns)
  end

  defp should_include?(item, current_path, include_patterns) do
    case include_patterns do
      nil -> true
      patterns ->
        full_path = Path.join(current_path, item)
        relative_path = Path.relative_to_cwd(full_path)

        # Direct match
        direct_match = matches_any_pattern?(item, patterns) ||
                      matches_any_pattern?(relative_path, patterns) ||
                      path_matches_glob?(relative_path, patterns)

        # If it's a directory, check if any pattern could match files inside it
        directory_could_contain_matches = File.dir?(full_path) &&
          Enum.any?(patterns, fn pattern ->
            pattern_could_match_under_directory?(pattern, relative_path)
          end)

        direct_match || directory_could_contain_matches
    end
  end

  defp pattern_could_match_under_directory?(pattern, directory_path) do
    cond do
      # For patterns like "lib/dia/application.ex", check if "lib" could lead to this file
      String.contains?(pattern, "/") ->
        pattern_parts = String.split(pattern, "/")
        directory_parts = String.split(directory_path, "/")

        # Check if the directory path is a prefix of the pattern path
        lists_have_common_prefix?(directory_parts, pattern_parts)

      # For simple patterns without /, they could match files anywhere
      true -> true
    end
  end

  defp lists_have_common_prefix?([], _), do: true
  defp lists_have_common_prefix?(_, []), do: false
  defp lists_have_common_prefix?([h1 | t1], [h2 | t2]) when h1 == h2 do
    lists_have_common_prefix?(t1, t2)
  end
  defp lists_have_common_prefix?([h1 | _], [h2 | _]) when h1 != h2, do: false

  defp path_matches_glob?(path, patterns) do
    Enum.any?(patterns, fn pattern ->
      # Check if the path is under a directory that matches the pattern
      cond do
        String.contains?(pattern, "**") ->
          # For patterns like "lib/dia/agent/**", check if path starts with "lib/dia/agent/"
          base_pattern = String.replace(pattern, "/**", "")
          String.starts_with?(path, base_pattern <> "/") || path == base_pattern

        String.ends_with?(pattern, "/*") ->
          # For patterns like "lib/dia/*", check if path is directly under that directory
          base_pattern = String.slice(pattern, 0..-3//1)
          String.starts_with?(path, base_pattern <> "/")

        true ->
          false
      end
    end)
  end

  defp matches_any_pattern?(item, patterns) when is_list(patterns) do
    Enum.any?(patterns, fn pattern ->
      try do
        # Handle glob patterns with **
        regex_pattern = cond do
          String.contains?(pattern, "**") ->
            # Convert ** to match any path depth
            pattern
            |> String.replace(~r/^\//, "") # Remove leading /
            |> String.replace(".", "\\.")
            |> String.replace("**", ".*")
            |> String.replace("*", "[^/]*")
            |> then(fn s -> "^#{s}$" end)

          true ->
            # Regular pattern matching
            pattern
            |> String.replace(~r/^\//, "") # Remove leading /
            |> String.replace(".", "\\.")
            |> String.replace("*", "[^/]*")
            |> then(fn s ->
              if String.ends_with?(s, "/") do
                dir_part = if String.length(s) > 1, do: String.slice(s, 0..-2//1), else: s
                "^#{dir_part}($|/.*)" # Directory match
              else
                "^#{s}$" # Exact file match
              end
            end)
        end

        Regex.match?(Regex.compile!(regex_pattern), item)
      rescue
        _ -> false # Skip invalid patterns
      end
    end)
  end
  defp matches_any_pattern?(_item, _patterns), do: false

  defp write_files_content(output_file, root, exclude_patterns, include_patterns) do
    root
    |> list_files(exclude_patterns, include_patterns)
    |> Enum.each(fn file ->
      try do
        content =
          file
          |> File.read!()
          |> String.replace("\r\n", @line_ending)
          |> String.replace("\r", @line_ending)

        relative_path = Path.relative_to_cwd(file)

        # Determine language for syntax highlighting
        language = case Path.extname(file) do
          ".ex" -> "elixir"
          ".exs" -> "elixir"
          ".js" -> "javascript"
          ".ts" -> "typescript"
          ".py" -> "python"
          ".rb" -> "ruby"
          ".go" -> "go"
          ".rs" -> "rust"
          ".java" -> "java"
          ".c" -> "c"
          ".cpp" -> "cpp"
          ".h" -> "c"
          ".css" -> "css"
          ".scss" -> "scss"
          ".html" -> "html"
          ".xml" -> "xml"
          ".json" -> "json"
          ".yaml" -> "yaml"
          ".yml" -> "yaml"
          ".sql" -> "sql"
          ".sh" -> "bash"
          ".md" -> "markdown"
          _ -> ""
        end

        write_section(output_file, "### #{relative_path}\n\n```#{language}\n#{content}\n```")
      rescue
        e ->
          Mix.shell().error("Failed to read file #{file}: #{inspect(e)}")
      end
    end)
  end

  defp list_files(root, exclude_patterns, include_patterns) do
    if File.dir?(root) do
      try do
        root
        |> File.ls!()
        |> Enum.reject(&should_exclude?(&1, root, exclude_patterns))
        |> Enum.filter(&should_include?(&1, root, include_patterns))
        |> Enum.flat_map(fn item ->
          list_files(Path.join(root, item), exclude_patterns, include_patterns)
        end)
      rescue
        e ->
          Mix.shell().error("Failed to list directory #{root}: #{inspect(e)}")
          []
      end
    else
      # Only include files that match include patterns (if specified) and don't match exclude patterns
      relative_path = Path.relative_to_cwd(root)
      basename = Path.basename(root)

      should_include_file = should_include?(basename, Path.dirname(root), include_patterns) ||
                           (include_patterns && path_matches_glob?(relative_path, include_patterns))

      should_exclude_file = should_exclude?(basename, Path.dirname(root), exclude_patterns)

      if should_include_file && !should_exclude_file do
        [root]
      else
        []
      end
    end
  end

  defp generate_notes_section(feature, include_patterns) do
    cond do
      # Feature-specific notes
      feature ->
        feature_notes = get_feature_specific_notes(feature)
        general_notes = get_general_elixir_notes()
        "## Notes for AI Analysis\n\n#{feature_notes}\n#{general_notes}"

      # General project notes when no feature specified
      include_patterns ->
        "## Notes for AI Analysis\n\n#{get_general_elixir_notes()}"

      # No notes for very basic usage
      true -> nil
    end
  end

  defp get_feature_specific_notes(feature) do
    case feature do
      "agent" -> """
**Agent Feature Context:**
- Look for `GenServer`, `Agent`, or `Task` implementations for stateful processes
- Check for supervision trees in application.ex or dedicated supervisors
- Agent modules typically handle state management and async operations
- Pay attention to process lifecycle, message passing, and error handling
"""

      "auth" -> """
**Authentication Feature Context:**
- Look for authentication pipelines, plugs, and middleware
- Check for token generation, validation, and refresh logic
- Review password hashing, session management, and security measures
- Pay attention to authorization rules and permission checking
"""

      "api" -> """
**API Feature Context:**
- Focus on Phoenix controllers, views, and serializers
- Check for API versioning, content negotiation, and response formatting
- Look for input validation, parameter parsing, and error handling
- Review rate limiting, authentication middleware, and CORS configuration
"""

      "frontend" -> """
**Frontend Feature Context:**
- Focus on Phoenix LiveView components and templates
- Check for JavaScript integration, asset pipeline, and CSS organization
- Look for form handling, real-time updates, and user interactions
- Review component composition and state management patterns
"""

      _ -> """
**#{String.capitalize(feature)} Feature Context:**
- This is a custom feature - analyze the included files for patterns and responsibilities
- Look for module boundaries, data flow, and integration points
- Check for supervision, error handling, and configuration management
"""
    end
  end

  defp get_general_elixir_notes do
    """

**General Elixir Project Reading Guide:**

**Application Structure:**
- `application.ex` defines the supervision tree and application startup
- `lib/` contains the core application modules
- `test/` contains unit and integration tests
- `config/` contains environment-specific configuration

**Module Conventions:**
- Module names follow the project namespace (e.g., `MyApp.Module`)
- GenServers handle stateful processes and long-running tasks
- Contexts group related functionality (e.g., `Accounts`, `Billing`)
- Schemas define data structures and database mappings

**Key Patterns:**
- `use` statements import common functionality
- `|>` pipe operator chains function calls
- Pattern matching in function heads for different cases
- `with` statements for happy path error handling
- Supervision trees for fault tolerance

**Testing:**
- Test files end with `_test.exs`
- ExUnit provides the testing framework
- Mocks and stubs are typically done with libraries like Mox
"""
  end
end
