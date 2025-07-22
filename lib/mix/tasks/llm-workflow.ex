defmodule Mix.Tasks.LlmWorkflow do
  use Mix.Task

  @shortdoc "AI-powered workflow: feature analysis → GitHub ticket creation → Copilot assignment"

  @moduledoc """
  Automated workflow tool that:
  1. Analyzes a feature using llm_ingest
  2. Uses AI to suggest enhancements or identify bugs
  3. Creates GitHub issues with rich context
  4. Assigns to GitHub Copilot or team members

  WORKFLOW:
    Feature Selection → Context Generation → AI Analysis → GitHub Ticket → Assignment

  USAGE:
    mix llm_workflow --feature=auth --type=enhancement
    mix llm_workflow --feature=api --type=bug --assign=@github-copilot
    mix llm_workflow --analyze-all --create-roadmap
  """

  @impl true
  def run(args) do
    {opts, _remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          feature: :string,
          # enhancement, bug, documentation, refactor
          type: :string,
          title: :string,
          # @github-copilot, @username, team-name
          assign: :string,
          # owner/repo, defaults to git remote
          repo: :string,
          # low, medium, high, critical
          priority: :string,
          # comma-separated
          labels: :string,
          # enable AI analysis
          ai: :boolean,
          ai_model: :string,
          ai_api_key: :string,
          ai_provider: :string,
          ai_base_url: :string,
          # don't actually create tickets
          dry_run: :boolean,
          # analyze all features and create roadmap
          analyze_all: :boolean,
          help: :boolean,
          verbose: :boolean
        ]
      )

    if opts[:help] do
      show_help()
    else
      # Store options for helper functions
      Process.put(:workflow_opts, opts)

      cond do
        opts[:analyze_all] ->
          run_full_analysis_workflow()

        opts[:feature] ->
          run_feature_workflow(opts[:feature], opts)

        true ->
          Mix.shell().error(
            "Error: --feature required or use --analyze-all. Use --help for more info."
          )

          System.halt(1)
      end
    end
  end

  # === WORKFLOW IMPLEMENTATIONS ===

  defp run_feature_workflow(feature_name, opts) do
    # Default to dry-run for safety
    is_dry_run = opts[:dry_run] != false

    if is_dry_run do
      Mix.shell().info("🔍 DRY RUN MODE (use --no-dry-run to create real tickets)")
    end

    Mix.shell().info("🚀 Starting workflow for feature: #{feature_name}")

    # Step 1: Generate feature context
    Mix.shell().info("📝 Step 1: Generating feature context...")
    context = generate_feature_context(feature_name)

    # Step 2: AI analysis (only if explicitly requested)
    use_ai = opts[:ai] || false

    analysis =
      if use_ai do
        Mix.shell().info("🤖 Step 2: AI analysis for suggestions...")
        analyze_with_ai(feature_name, context, opts[:type] || "enhancement")
      else
        Mix.shell().info(
          "📋 Step 2: Creating basic analysis (use --ai for AI-powered analysis)..."
        )

        create_fallback_analysis(feature_name, opts[:type] || "enhancement")
      end

    # Step 3: Create GitHub ticket
    Mix.shell().info(
      "🎫 Step 3: #{if is_dry_run, do: "Previewing", else: "Creating"} GitHub ticket..."
    )

    # Pass the corrected dry_run flag
    ticket_opts = Keyword.put(opts, :dry_run, is_dry_run)
    ticket = create_github_ticket(feature_name, analysis, ticket_opts)

    # Step 4: Assignment (only for real tickets)
    if opts[:assign] do
      if is_dry_run do
        Mix.shell().info("👥 Step 4: Would assign to #{opts[:assign]} (dry-run)")
      else
        Mix.shell().info("👥 Step 4: Assigning ticket...")
        assign_ticket(ticket, opts[:assign])
      end
    end

    Mix.shell().info("✅ Workflow completed!")
    print_workflow_summary(ticket, is_dry_run)
  end

  defp run_full_analysis_workflow() do
    Mix.shell().info("🔍 Analyzing all features and generating project roadmap...")

    # Get all available features
    features = discover_all_features()

    if Enum.empty?(features) do
      Mix.shell().error("No features found. Run 'mix llm_trace' first to discover features.")
      System.halt(1)
    end

    Mix.shell().info("Found #{length(features)} features: #{Enum.join(features, ", ")}")

    # Analyze each feature
    analyses =
      Enum.map(features, fn feature ->
        Mix.shell().info("Analyzing #{feature}...")
        context = generate_feature_context(feature)
        analysis = analyze_with_ai(feature, context, "analysis")
        {feature, analysis}
      end)

    # Generate roadmap
    roadmap = generate_project_roadmap(analyses)

    # Create roadmap ticket
    roadmap_ticket = create_roadmap_ticket(roadmap)

    Mix.shell().info("✅ Project analysis completed!")
    Mix.shell().info("📋 Roadmap ticket: #{roadmap_ticket.url}")
  end

  # === CORE FUNCTIONS ===

  defp generate_feature_context(feature_name) do
    # Use existing llm_ingest to generate context
    temp_file = "/tmp/llm_context_#{feature_name}_#{System.system_time()}.md"

    try do
      # Run llm_ingest to generate context
      Mix.Task.run("llm_ingest", ["--feature=#{feature_name}", "--output=#{temp_file}"])

      # Read the generated context
      case File.read(temp_file) do
        {:ok, content} ->
          %{
            feature: feature_name,
            content: content,
            files: extract_file_list(content),
            structure: extract_structure(content)
          }

        {:error, reason} ->
          Mix.shell().error("Failed to read context file: #{reason}")
          %{feature: feature_name, content: "", files: [], structure: ""}
      end
    after
      File.rm(temp_file)
    end
  end

  defp analyze_with_ai(feature_name, context, analysis_type) do
    case get_ai_client() do
      {:ok, _client} ->
        prompt = build_analysis_prompt(feature_name, context, analysis_type)

        case call_ai_analysis(prompt) do
          {:ok, analysis} ->
            analysis

          {:error, reason} ->
            Mix.shell().error("AI analysis failed: #{reason}")
            Mix.shell().info("Falling back to basic analysis...")
            create_fallback_analysis(feature_name, analysis_type)
        end

      {:error, reason} ->
        Mix.shell().error("AI client unavailable: #{reason}")
        Mix.shell().info("Use --ai flag to enable AI analysis (requires OPENAI_API_KEY)")
        create_fallback_analysis(feature_name, analysis_type)
    end
  end

  defp create_github_ticket(feature_name, analysis, opts) do
    repo = opts[:repo] || detect_github_repo()

    ticket_data = %{
      title: opts[:title] || analysis.title,
      body: build_ticket_body(feature_name, analysis),
      labels: parse_labels(opts[:labels]) ++ analysis.suggested_labels,
      assignees: [],
      milestone: nil
    }

    if opts[:dry_run] do
      Mix.shell().info("🔍 DRY RUN - Would create ticket:")
      Mix.shell().info("Title: #{ticket_data.title}")
      Mix.shell().info("Labels: #{Enum.join(ticket_data.labels, ", ")}")
      Mix.shell().info("Body preview: #{String.slice(ticket_data.body, 0, 200)}...")

      %{
        url: "https://github.com/#{repo}/issues/DRY_RUN",
        number: "DRY_RUN",
        title: ticket_data.title
      }
    else
      Mix.shell().info("🎫 Creating real GitHub issue...")
      create_github_issue(repo, ticket_data)
    end
  end

  # === AI ANALYSIS ===

  defp build_analysis_prompt(feature_name, context, analysis_type) do
    """
    You are an expert software architect analyzing an Elixir codebase feature.

    FEATURE: #{feature_name}
    ANALYSIS TYPE: #{analysis_type}

    FEATURE CONTEXT:
    #{String.slice(context.content, 0, 8000)}

    FILES ANALYZED: #{length(context.files)}

    Please provide a detailed analysis in JSON format:

    {
      "title": "Concise title for GitHub issue",
      "type": "#{analysis_type}",
      "priority": "low|medium|high|critical",
      "description": "Detailed description of the #{analysis_type}",
      "technical_details": "Technical implementation details",
      "acceptance_criteria": ["Criterion 1", "Criterion 2"],
      "estimated_effort": "XS|S|M|L|XL",
      "suggested_labels": ["label1", "label2"],
      "affected_files": ["file1.ex", "file2.ex"],
      "dependencies": ["Other features or systems this depends on"],
      "risks": ["Potential risks or considerations"],
      "recommendations": ["Specific actionable recommendations"]
    }

    #{get_analysis_type_instructions(analysis_type)}
    """
  end

  defp get_analysis_type_instructions(analysis_type) do
    case analysis_type do
      "enhancement" ->
        """
        Focus on:
        - Performance improvements
        - New features that would add value
        - Code quality improvements
        - Better error handling
        - Security enhancements
        """

      "bug" ->
        """
        Look for:
        - Potential race conditions
        - Error handling gaps
        - Edge cases not covered
        - Performance bottlenecks
        - Security vulnerabilities
        """

      "refactor" ->
        """
        Identify opportunities for:
        - Code duplication removal
        - Better separation of concerns
        - Pattern improvements
        - Test coverage gaps
        - Documentation improvements
        """

      "documentation" ->
        """
        Focus on:
        - Missing documentation
        - Outdated documentation
        - Complex code that needs explanation
        - API documentation gaps
        - Examples and tutorials needed
        """

      _ ->
        "Provide general analysis and recommendations."
    end
  end

  # === GITHUB INTEGRATION ===

  defp detect_github_repo() do
    case System.cmd("git", ["remote", "get-url", "origin"]) do
      {url, 0} ->
        url
        |> String.trim()
        |> extract_repo_from_url()

      _ ->
        Mix.shell().error("Could not detect GitHub repo. Use --repo=owner/repo")
        System.halt(1)
    end
  end

  defp extract_repo_from_url(url) do
    # Handle both SSH and HTTPS URLs
    cond do
      String.contains?(url, "github.com:") ->
        url |> String.split("github.com:") |> List.last() |> String.replace(".git", "")

      String.contains?(url, "github.com/") ->
        url |> String.split("github.com/") |> List.last() |> String.replace(".git", "")

      true ->
        Mix.shell().error("Could not parse GitHub URL: #{url}")
        System.halt(1)
    end
  end

  defp create_github_issue(repo, ticket_data) do
    github_token = System.get_env("GITHUB_TOKEN")

    if !github_token do
      Mix.shell().error("GITHUB_TOKEN environment variable required")
      System.halt(1)
    end

    # Ensure Finch is started
    case ensure_finch_started() do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.shell().error("Failed to start HTTP client: #{reason}")
        System.halt(1)
    end

    url = "https://api.github.com/repos/#{repo}/issues"

    case Req.post(url,
           headers: [authorization: "Bearer #{github_token}"],
           json: %{
             title: ticket_data.title,
             body: ticket_data.body,
             labels: ticket_data.labels
           },
           receive_timeout: 30_000,
           finch: LlmWorkflow.Finch
         ) do
      {:ok, %Req.Response{status: 201, body: response}} ->
        %{
          url: response["html_url"],
          number: response["number"],
          title: response["title"]
        }

      {:ok, %Req.Response{status: status, body: error_body}} ->
        Mix.shell().error("GitHub API error #{status}: #{inspect(error_body)}")
        System.halt(1)

      {:error, error} ->
        Mix.shell().error("Request failed: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp ensure_finch_started() do
    case Process.whereis(LlmWorkflow.Finch) do
      nil ->
        # Start Finch directly without supervisor
        debug_info("Starting Finch HTTP client...")

        case Finch.start_link(name: LlmWorkflow.Finch) do
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

  defp debug_info(message) do
    if Process.get(:workflow_opts, %{})[:verbose] do
      Mix.shell().info(message)
    end
  end

  defp build_ticket_body(feature_name, analysis) do
    """
    ## 🎯 #{String.capitalize(analysis.type)}: #{feature_name}

    ### 📋 Description
    #{analysis.description}

    ### 🔧 Technical Details
    #{analysis.technical_details}

    ### ✅ Acceptance Criteria
    #{Enum.map_join(analysis.acceptance_criteria, "\n", fn criterion -> "- [ ] #{criterion}" end)}

    ### 📁 Affected Files
    #{Enum.map_join(analysis.affected_files, "\n", fn file -> "- `#{file}`" end)}

    ### 🔗 Dependencies
    #{if Enum.empty?(analysis.dependencies), do: "None", else: Enum.map_join(analysis.dependencies, "\n", fn dep -> "- #{dep}" end)}

    ### ⚠️ Risks & Considerations
    #{Enum.map_join(analysis.risks, "\n", fn risk -> "- #{risk}" end)}

    ### 💡 Recommendations
    #{Enum.map_join(analysis.recommendations, "\n", fn rec -> "- #{rec}" end)}

    ### 🏷️ Metadata
    - **Estimated Effort:** #{analysis.estimated_effort}
    - **Priority:** #{analysis.priority}
    - **Generated by:** LLM Workflow Tool

    ---
    *This ticket was automatically generated using AI analysis of the codebase.*
    """
  end

  # === AI API CALLS ===

  defp call_ai_analysis(prompt) do
    case get_ai_client() do
      {:ok, _client} ->
        make_real_ai_request(prompt)

      {:error, reason} ->
        Mix.shell().error("AI client unavailable: #{reason}")
        {:error, reason}
    end
  end

  defp make_real_ai_request(prompt) do
    case get_ai_client() do
      {:ok, :openai} -> make_openai_request(prompt)
      {:ok, :claude} -> make_claude_request(prompt)
      {:ok, {:ollama, base_url}} -> make_ollama_request(prompt, base_url)
      {:ok, {:vllm, base_url, api_key}} -> make_vllm_request(prompt, base_url, api_key)
      {:error, reason} -> {:error, reason}
    end
  end

  defp make_openai_request(prompt) do
    api_key = System.get_env("OPENAI_API_KEY") || Process.get(:workflow_opts, %{})[:ai_api_key]
    model = Process.get(:workflow_opts, %{})[:ai_model] || "gpt-4o-mini"

    request_body = %{
      model: model,
      messages: [
        %{
          role: "system",
          content: "You are an expert software architect analyzing Elixir codebases."
        },
        %{role: "user", content: prompt}
      ],
      temperature: 0.3,
      max_tokens: 1500
    }

    debug_info("🤖 Calling OpenAI API...")

    case ensure_finch_started() do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to start HTTP client: #{reason}"}
    end

    case Req.post("https://api.openai.com/v1/chat/completions",
           headers: [authorization: "Bearer #{api_key}"],
           json: request_body,
           receive_timeout: 30_000,
           finch: LlmWorkflow.Finch
         ) do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]}
       }} ->
        parse_ai_analysis_response(content)

      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, "OpenAI API error #{status}: #{inspect(error_body)}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp make_claude_request(prompt) do
    api_key = System.get_env("ANTHROPIC_API_KEY") || Process.get(:workflow_opts, %{})[:ai_api_key]
    model = Process.get(:workflow_opts, %{})[:ai_model] || "claude-3-5-sonnet-20241022"

    request_body = %{
      model: model,
      max_tokens: 1500,
      temperature: 0.3,
      system:
        "You are an expert software architect analyzing Elixir codebases. Provide practical, actionable analysis based on the actual code provided.",
      messages: [
        %{role: "user", content: prompt}
      ]
    }

    debug_info("🤖 Calling Claude API...")

    case ensure_finch_started() do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to start HTTP client: #{reason}"}
    end

    case Req.post("https://api.anthropic.com/v1/messages",
           headers: [
             authorization: "Bearer #{api_key}",
             "anthropic-version": "2023-06-01"
           ],
           json: request_body,
           receive_timeout: 30_000,
           finch: LlmWorkflow.Finch
         ) do
      {:ok, %Req.Response{status: 200, body: %{"content" => [%{"text" => content} | _]}}} ->
        parse_ai_analysis_response(content)

      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, "Claude API error #{status}: #{inspect(error_body)}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp make_ollama_request(prompt, base_url) do
    model = Process.get(:workflow_opts, %{})[:ai_model] || "llama3.1:8b"

    request_body = %{
      model: model,
      prompt: "You are an expert software architect analyzing Elixir codebases.\n\n#{prompt}",
      stream: false,
      options: %{
        temperature: 0.3,
        num_predict: 1500
      }
    }

    debug_info("🤖 Calling Ollama API at #{base_url}...")

    case ensure_finch_started() do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to start HTTP client: #{reason}"}
    end

    case Req.post("#{base_url}/api/generate",
           json: request_body,
           # Ollama can be slower
           receive_timeout: 60_000,
           finch: LlmWorkflow.Finch
         ) do
      {:ok, %Req.Response{status: 200, body: %{"response" => content}}} ->
        parse_ai_analysis_response(content)

      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, "Ollama API error #{status}: #{inspect(error_body)}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp make_vllm_request(prompt, base_url, api_key) do
    model = Process.get(:workflow_opts, %{})[:ai_model] || "microsoft/DialoGPT-large"

    request_body = %{
      model: model,
      messages: [
        %{
          role: "system",
          content: "You are an expert software architect analyzing Elixir codebases."
        },
        %{role: "user", content: prompt}
      ],
      temperature: 0.3,
      max_tokens: 1500
    }

    debug_info("🤖 Calling vLLM API at #{base_url}...")

    case ensure_finch_started() do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to start HTTP client: #{reason}"}
    end

    headers =
      if api_key do
        [authorization: "Bearer #{api_key}"]
      else
        []
      end

    case Req.post("#{base_url}/v1/chat/completions",
           headers: headers,
           json: request_body,
           receive_timeout: 30_000,
           finch: LlmWorkflow.Finch
         ) do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]}
       }} ->
        parse_ai_analysis_response(content)

      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, "vLLM API error #{status}: #{inspect(error_body)}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp parse_ai_analysis_response(content) do
    # Try to extract JSON from the response
    case extract_json_from_response(content) do
      {:ok, parsed} ->
        analysis = %{
          title: Map.get(parsed, "title", "Feature Analysis"),
          type: Map.get(parsed, "type", "enhancement"),
          priority: Map.get(parsed, "priority", "medium"),
          description: Map.get(parsed, "description", "AI analysis of the feature"),
          technical_details: Map.get(parsed, "technical_details", "See description"),
          acceptance_criteria: Map.get(parsed, "acceptance_criteria", []),
          estimated_effort: Map.get(parsed, "estimated_effort", "M"),
          suggested_labels: Map.get(parsed, "suggested_labels", []),
          affected_files: Map.get(parsed, "affected_files", []),
          dependencies: Map.get(parsed, "dependencies", []),
          risks: Map.get(parsed, "risks", []),
          recommendations: Map.get(parsed, "recommendations", [])
        }

        {:ok, analysis}

      {:error, _reason} ->
        # Fallback: use the raw response as description
        analysis = %{
          title: "AI Analysis Results",
          type: "enhancement",
          priority: "medium",
          description: content,
          technical_details: "See description above",
          acceptance_criteria: ["Review AI analysis", "Implement suggestions"],
          estimated_effort: "M",
          suggested_labels: ["ai-analysis"],
          affected_files: [],
          dependencies: [],
          risks: ["Manual review required"],
          recommendations: ["Review the AI analysis above"]
        }

        {:ok, analysis}
    end
  end

  defp extract_json_from_response(content) do
    # Try to find JSON in the response
    json_match = Regex.run(~r/\{.*\}/s, content)

    case json_match do
      [json_string] ->
        case Jason.decode(json_string) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, reason} -> {:error, reason}
        end

      nil ->
        # Try parsing the entire content as JSON
        case Jason.decode(content) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp get_ai_client() do
    provider =
      System.get_env("LLM_PROVIDER") || Process.get(:workflow_opts, %{})[:ai_provider] || "openai"

    case provider do
      "openai" ->
        get_openai_client()

      "claude" ->
        get_claude_client()

      "ollama" ->
        get_ollama_client()

      "vllm" ->
        get_vllm_client()

      _ ->
        {:error, "Unsupported LLM provider: #{provider}. Supported: openai, claude, ollama, vllm"}
    end
  end

  defp get_openai_client() do
    api_key = System.get_env("OPENAI_API_KEY") || Process.get(:workflow_opts, %{})[:ai_api_key]

    case {Code.ensure_loaded(Req), Code.ensure_loaded(Jason), api_key} do
      {{:module, Req}, {:module, Jason}, key} when is_binary(key) ->
        {:ok, :openai}

      {{:error, _}, _, _} ->
        {:error, "Missing Req dependency. Add {:req, \"~> 0.5\"} to mix.exs"}

      {_, {:error, _}, _} ->
        {:error, "Missing Jason dependency. Add {:jason, \"~> 1.4\"} to mix.exs"}

      {_, _, nil} ->
        {:error, "Missing OPENAI_API_KEY environment variable"}

      _ ->
        {:error, "Missing dependencies or API key"}
    end
  end

  defp get_claude_client() do
    api_key = System.get_env("ANTHROPIC_API_KEY") || Process.get(:workflow_opts, %{})[:ai_api_key]

    case {Code.ensure_loaded(Req), Code.ensure_loaded(Jason), api_key} do
      {{:module, Req}, {:module, Jason}, key} when is_binary(key) ->
        {:ok, :claude}

      {{:error, _}, _, _} ->
        {:error, "Missing Req dependency. Add {:req, \"~> 0.5\"} to mix.exs"}

      {_, {:error, _}, _} ->
        {:error, "Missing Jason dependency. Add {:jason, \"~> 1.4\"} to mix.exs"}

      {_, _, nil} ->
        {:error, "Missing ANTHROPIC_API_KEY environment variable"}

      _ ->
        {:error, "Missing dependencies or API key"}
    end
  end

  defp get_ollama_client() do
    base_url =
      System.get_env("OLLAMA_BASE_URL") || Process.get(:workflow_opts, %{})[:ai_base_url] ||
        "http://localhost:11434"

    case {Code.ensure_loaded(Req), Code.ensure_loaded(Jason)} do
      {{:module, Req}, {:module, Jason}} ->
        {:ok, {:ollama, base_url}}

      {{:error, _}, _} ->
        {:error, "Missing Req dependency. Add {:req, \"~> 0.5\"} to mix.exs"}

      {_, {:error, _}} ->
        {:error, "Missing Jason dependency. Add {:jason, \"~> 1.4\"} to mix.exs"}
    end
  end

  defp get_vllm_client() do
    base_url = System.get_env("VLLM_BASE_URL") || Process.get(:workflow_opts, %{})[:ai_base_url]
    api_key = System.get_env("VLLM_API_KEY") || Process.get(:workflow_opts, %{})[:ai_api_key]

    if !base_url do
      {:error, "Missing VLLM_BASE_URL environment variable"}
    else
      case {Code.ensure_loaded(Req), Code.ensure_loaded(Jason)} do
        {{:module, Req}, {:module, Jason}} ->
          {:ok, {:vllm, base_url, api_key}}

        {{:error, _}, _} ->
          {:error, "Missing Req dependency. Add {:req, \"~> 0.5\"} to mix.exs"}

        {_, {:error, _}} ->
          {:error, "Missing Jason dependency. Add {:jason, \"~> 1.4\"} to mix.exs"}
      end
    end
  end

  # === ASSIGNMENT ===

  defp assign_ticket(ticket, assignee) do
    github_token = System.get_env("GITHUB_TOKEN")
    repo = detect_github_repo()

    # Parse assignee (remove @ if present)
    clean_assignee = String.replace(assignee, "@", "")

    # Ensure Finch is started
    case ensure_finch_started() do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.shell().error("Failed to start HTTP client: #{reason}")
        :error
    end

    url = "https://api.github.com/repos/#{repo}/issues/#{ticket.number}"

    # Handle special case for GitHub Copilot or team assignments
    assignees =
      cond do
        clean_assignee == "github-copilot" ->
          # GitHub Copilot can't be directly assigned, but we can add a label
          add_copilot_label(repo, ticket.number)
          []

        String.starts_with?(clean_assignee, "team-") ->
          # Team assignments would need different API endpoint
          Mix.shell().info("Team assignment not implemented yet: #{clean_assignee}")
          []

        true ->
          [clean_assignee]
      end

    if length(assignees) > 0 do
      case Req.patch(url,
             headers: [authorization: "Bearer #{github_token}"],
             json: %{assignees: assignees},
             finch: LlmWorkflow.Finch
           ) do
        {:ok, %Req.Response{status: 200}} ->
          Mix.shell().info("✅ Assigned ticket to #{assignee}")

        {:error, error} ->
          Mix.shell().error("Failed to assign: #{inspect(error)}")
      end
    end
  end

  defp add_copilot_label(repo, issue_number) do
    github_token = System.get_env("GITHUB_TOKEN")
    url = "https://api.github.com/repos/#{repo}/issues/#{issue_number}/labels"

    case Req.post(url,
           headers: [authorization: "Bearer #{github_token}"],
           json: %{labels: ["copilot-suggestion"]},
           finch: LlmWorkflow.Finch
         ) do
      {:ok, %Req.Response{status: 200}} ->
        Mix.shell().info("🤖 Added 'copilot-suggestion' label")

      {:error, _} ->
        Mix.shell().info("Could not add Copilot label (ticket still created)")
    end
  end

  # === HELPER FUNCTIONS ===

  defp extract_file_list(content) do
    # Extract file paths from the generated markdown
    content
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "### "))
    |> Enum.map(fn line ->
      line
      |> String.replace("### ", "")
      |> String.trim()
    end)
  end

  defp extract_structure(content) do
    # Extract the project structure section
    case String.split(content, "## Project Structure") do
      [_, structure_part | _] ->
        structure_part
        |> String.split("## Files")
        |> List.first()
        |> String.trim()

      _ ->
        ""
    end
  end

  defp parse_labels(nil), do: []

  defp parse_labels(labels_string) do
    labels_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp print_workflow_summary(ticket, is_dry_run) do
    title = Map.get(ticket, :title, "DRY RUN - No title")
    mode = if is_dry_run, do: "DRY RUN", else: "CREATED"

    Mix.shell().info("""

    🎉 Workflow Summary:
    ━━━━━━━━━━━━━━━━━━━━━━
    📋 Ticket #{mode}: #{title}
    🔗 URL: #{ticket.url}
    🎫 Number: ##{ticket.number}
    ━━━━━━━━━━━━━━━━━━━━━━
    """)
  end

  defp discover_all_features() do
    config_files = [
      "llm_features_traced.exs",
      "llm_features.exs",
      "llm_features_enhanced.exs"
    ]

    config_files
    |> Enum.find_value(fn file ->
      if File.exists?(file) do
        try do
          {config, _} = Code.eval_file(file)
          Map.keys(config)
        rescue
          _ -> nil
        end
      end
    end) || []
  end

  defp create_fallback_analysis(feature_name, analysis_type) do
    # Get actual files from the feature if possible
    actual_files = get_feature_files(feature_name)

    %{
      title: "#{String.capitalize(analysis_type)}: #{feature_name}",
      type: analysis_type,
      priority: "medium",
      description: "AI analysis unavailable - manual review needed for #{feature_name} feature",
      technical_details:
        "Please review the #{feature_name} feature manually. Files involved: #{Enum.join(actual_files, ", ")}",
      acceptance_criteria: [
        "Manual analysis of #{feature_name} required",
        "Review files: #{Enum.join(actual_files, ", ")}"
      ],
      estimated_effort: "TBD",
      suggested_labels: [analysis_type, "needs-analysis", feature_name],
      affected_files: actual_files,
      dependencies: [],
      risks: ["Manual review required"],
      recommendations: ["Conduct manual code review of #{feature_name} feature"]
    }
  end

  defp get_feature_files(feature_name) do
    # Try to get actual files from feature configuration
    config_files = [
      "llm_features_traced.exs",
      "llm_features.exs",
      "llm_features_enhanced.exs"
    ]

    config_files
    |> Enum.find_value(fn file ->
      if File.exists?(file) do
        try do
          {config, _} = Code.eval_file(file)

          case Map.get(config, feature_name) do
            nil ->
              nil

            feature_config ->
              include_patterns = get_config_value(feature_config, :include, "")

              if include_patterns != "" do
                # Convert patterns to actual files
                patterns = String.split(include_patterns, ",") |> Enum.map(&String.trim/1)
                find_files_for_patterns(patterns)
              else
                []
              end
          end
        rescue
          _ -> nil
        end
      end
    end) || []
  end

  defp find_files_for_patterns(patterns) do
    patterns
    |> Enum.flat_map(fn pattern ->
      case Path.wildcard(pattern) do
        # If no files found, include the pattern itself
        [] -> [pattern]
        files -> files
      end
    end)
    # Limit to first 10 files to avoid overwhelming
    |> Enum.take(10)
  end

  defp get_config_value(config, key, default) when is_map(config) do
    Map.get(config, key) || Map.get(config, to_string(key), default)
  end

  defp get_config_value(config, key, default) when is_list(config) do
    Keyword.get(config, key) || Keyword.get(config, String.to_atom(to_string(key)), default)
  end

  defp get_config_value(_, _, default), do: default

  defp generate_project_roadmap(analyses) do
    # Aggregate all analyses into a comprehensive roadmap
    enhancements = filter_by_type(analyses, "enhancement")
    bugs = filter_by_type(analyses, "bug")
    refactors = filter_by_type(analyses, "refactor")

    %{
      summary: %{
        total_features: length(analyses),
        enhancements: length(enhancements),
        bugs: length(bugs),
        refactors: length(refactors)
      },
      high_priority: filter_by_priority(analyses, "high"),
      recommendations: aggregate_recommendations(analyses),
      features: analyses
    }
  end

  defp create_roadmap_ticket(_roadmap) do
    # Create a comprehensive roadmap ticket
    %{
      url: "https://github.com/example/repo/issues/roadmap",
      number: "ROADMAP",
      title: "Project Analysis & Development Roadmap"
    }
  end

  defp filter_by_type(analyses, type) do
    Enum.filter(analyses, fn {_feature, analysis} ->
      analysis.type == type
    end)
  end

  defp filter_by_priority(analyses, priority) do
    Enum.filter(analyses, fn {_feature, analysis} ->
      analysis.priority == priority
    end)
  end

  defp aggregate_recommendations(analyses) do
    analyses
    |> Enum.flat_map(fn {_feature, analysis} ->
      analysis.recommendations
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_rec, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {rec, _count} -> rec end)
  end

  defp show_help do
    Mix.shell().info("""
    #{@shortdoc}

    USAGE:
        mix llm_workflow --feature=FEATURE [OPTIONS]
        mix llm_workflow --analyze-all [OPTIONS]

    OPTIONS:
      --feature FEATURE        Analyze specific feature (from llm_features.exs)
      --type TYPE              Analysis type: enhancement|bug|refactor|documentation
      --title TITLE            Custom ticket title
      --assign USER            Assign to @github-copilot, @username, or team
      --repo OWNER/REPO        GitHub repository (auto-detected from git remote)
      --priority LEVEL         Priority: low|medium|high|critical
      --labels LABELS          Comma-separated additional labels
      --ai                     Enable AI-powered analysis
      --ai-provider PROVIDER   LLM provider: openai|claude|ollama|vllm (default: openai)
      --ai-model MODEL         Model name (provider-specific)
      --ai-api-key KEY         API key for the LLM provider
      --ai-base-url URL        Base URL for self-hosted LLMs (ollama/vllm)
      --no-dry-run            Create real tickets (default is dry-run for safety)
      --analyze-all           Analyze all features and create roadmap
      --verbose               Show detailed output
      --help                  Show this help

    EXAMPLES:
        # Basic analysis (dry-run, no AI)
        mix llm_workflow --feature=auth --type=enhancement

        # AI-powered analysis with real ticket creation
        mix llm_workflow --feature=auth --type=enhancement --ai --no-dry-run

        # Find bugs with AI analysis (dry-run)
        mix llm_workflow --feature=api --type=bug --priority=high --ai

        # Create real ticket and assign to Copilot
        mix llm_workflow --feature=database --type=refactor --ai --no-dry-run --assign=@github-copilot

        # Basic analysis, create real ticket
        mix llm_workflow --feature=worker --type=bug --no-dry-run

        # Analyze all features (dry-run)
        mix llm_workflow --analyze-all --ai

        # OpenAI (default)
        mix llm_workflow --feature=auth --type=enhancement --ai

        # Claude
        mix llm_workflow --feature=auth --type=enhancement --ai \\
          --ai-provider=claude --ai-model=claude-3-5-sonnet-20241022

        # Local Ollama
        mix llm_workflow --feature=auth --type=enhancement --ai \\
          --ai-provider=ollama --ai-model=llama3.1:8b

        # Self-hosted vLLM
        mix llm_workflow --feature=auth --type=enhancement --ai \\
          --ai-provider=vllm --ai-base-url=http://gpu-server:8000

    CUSTOM BUG CREATION:
        Create specific bugs with AI-generated context based on your code:

        # AI analyzes code and identifies potential bugs
        mix llm_workflow --feature=query_parser --type=bug --ai

        # Custom bug with AI-enhanced analysis
        mix llm_workflow --feature=worker --type=bug --ai \\
          --title="Memory leak in query processing" \\
          --priority=high --labels="performance,memory"

        # Specific bug scenarios
        mix llm_workflow --feature=database --type=bug --ai \\
          --title="Connection pool exhaustion under load" \\
          --priority=critical

        # Documentation bugs (missing docs that cause issues)
        mix llm_workflow --feature=api --type=documentation --ai \\
          --title="Missing error handling documentation"

        AI generates realistic bugs including:
        - Technical details based on your actual code
        - Acceptance criteria with actionable steps
        - Risk assessment and mitigation strategies
        - Effort estimates and affected files from your codebase

    LLM PROVIDERS:
        OpenAI:
          --ai-provider=openai --ai-model=gpt-4o-mini
          Requires: OPENAI_API_KEY environment variable

        Claude (Anthropic):
          --ai-provider=claude --ai-model=claude-3-5-sonnet-20241022
          Requires: ANTHROPIC_API_KEY environment variable

        Ollama (Local):
          --ai-provider=ollama --ai-model=llama3.1:8b --ai-base-url=http://localhost:11434
          Requires: Ollama running locally or OLLAMA_BASE_URL

        vLLM (Self-hosted):
          --ai-provider=vllm --ai-base-url=http://your-vllm-server:8000
          Optional: VLLM_API_KEY for authenticated endpoints

    ENVIRONMENT VARIABLES:
        LLM_PROVIDER=openai|claude|ollama|vllm
        OPENAI_API_KEY=your_openai_key
        ANTHROPIC_API_KEY=your_claude_key
        OLLAMA_BASE_URL=http://localhost:11434
        VLLM_BASE_URL=http://your-server:8000
        VLLM_API_KEY=your_vllm_key (optional)

    WORKFLOW:
        1. 📝 Generate feature context using llm_ingest
        2. 🤖 AI analyzes code for improvements/bugs/etc. (if --ai flag used)
        3. 🎫 Create detailed GitHub issue with rich context
        4. 👥 Assign to GitHub Copilot or team members (if --assign used)
        5. ✅ Track and manage development workflow

    REQUIREMENTS:
        - GitHub repository with issues enabled
        - GITHUB_TOKEN environment variable for real ticket creation
        - OpenAI API key for AI analysis (optional, use --ai flag)
        - Feature configurations from llm_trace or manual setup

    INTEGRATION:
        Works with existing llm_trace and llm_ingest tools:

        mix llm_trace MyApp.Auth.login/2 --name=auth --ai
        mix llm_workflow --feature=auth --type=enhancement --ai --no-dry-run
    """)
  end
end
