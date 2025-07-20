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
      feature_section = "## Feature: #{opts[:feature]}\n\n" <>
        case feature_include do
          nil -> "Feature configuration not found or invalid."
          patterns ->
            include_text = "**Include patterns:** `#{Enum.join(patterns, "`, `")}`\n\n"
            exclude_text = case feature_exclude do
              [] -> ""
              excludes -> "**Exclude patterns:** `#{Enum.join(excludes, "`, `")}`\n\n"
            end
            include_text <> exclude_text
        end
      write_section(output_file, feature_section)
    end

    # Add folder structure section with markdown header
    write_section(output_file, "## Project Structure\n\n```\n#{generate_folder_structure(root, all_excludes, include_patterns)}```")

    # Add files section header
    write_section(output_file, "## Files")

    write_files_content(output_file, root, all_excludes, include_patterns)

    Mix.shell().info("Generated #{output_file}")
  end

  defp load_feature_config(nil, _root), do: {nil, []}
  defp load_feature_config(feature_name, root) do
    config_file = Path.join(root, "llm_features.exs")

    if File.exists?(config_file) do
      try do
        {features_config, _} = Code.eval_file(config_file)

        case Map.get(features_config, feature_name) do
          nil ->
            Mix.shell().error("Feature '#{feature_name}' not found in llm_features.exs")
            available_features = Map.keys(features_config) |> Enum.join(", ")
            Mix.shell().info("Available features: #{available_features}")
            {nil, []}

          feature_config ->
            include_patterns = parse_patterns(feature_config[:include])
            exclude_patterns = parse_patterns(feature_config[:exclude]) || []
            Mix.shell().info("Loaded feature '#{feature_name}' with #{length(include_patterns || [])} include patterns")
            Mix.shell().info("Include patterns: #{inspect(include_patterns)}")
            {include_patterns, exclude_patterns}
        end
      rescue
        e ->
          Mix.shell().error("Failed to load llm_features.exs: #{inspect(e)}")
          {nil, []}
      end
    else
      Mix.shell().error("Feature configuration file 'llm_features.exs' not found in project root")
      Mix.shell().info("Create llm_features.exs with your feature definitions")
      print_example_config()
      {nil, []}
    end
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

      # Debug output
      if is_root and include_patterns do
        all_children = File.ls!(path)
        Mix.shell().info("Root directory children: #{inspect(all_children)}")
        Mix.shell().info("After filtering: #{inspect(children)}")
      end

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
end
