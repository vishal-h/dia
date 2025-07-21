%{
  "agent" => %{
    include: "lib/dia/application.ex,lib/dia/agent/**,lib/dia/llm/**",
    exclude: "**/*_test.exs"
  },
  "mix_task" => %{
    include: "lib/mix/tasks/**"
    # exclude: "**/*_test.exs"
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
