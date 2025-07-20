# Mix.Tasks.LlmIngest

A powerful Mix task for generating LLM-friendly code ingestion files. This tool creates well-structured markdown files containing your project's source code, making it easy to share context with Large Language Models for code analysis, debugging, or feature development.

## Features

- 🎯 **Feature-based filtering** - Focus on specific parts of your codebase using predefined configurations
- 📁 **Smart directory traversal** - ASCII tree structure with proper file organization
- 🎨 **Markdown output** - Clean formatting with syntax highlighting for different file types
- 🚫 **Intelligent exclusions** - Built-in patterns for common artifacts (build files, dependencies, etc.)
- 📝 **Gitignore integration** - Automatically respects your .gitignore patterns
- 🔧 **Highly configurable** - Custom include/exclude patterns and output locations

## Installation

### Option 1: Add to existing Elixir project

1. Add the task file to your project:
   ```bash
   mkdir -p lib/mix/tasks
   # Copy the llm_ingest.ex file to lib/mix/tasks/
   ```

2. The task will be automatically available as a Mix command

### Option 2: Install as dependency (future enhancement)
```elixir
# In your mix.exs
def deps do
  [
    {:llm_ingest, "~> 0.1.0"}
  ]
end
```

### Option 3: Copy to any Elixir project

1. Create the task directory:
   ```bash
   mkdir -p lib/mix/tasks
   ```

2. Copy the `llm_ingest.ex` file to `lib/mix/tasks/llm_ingest.ex`

3. Compile your project:
   ```bash
   mix compile
   ```

4. The task is now available:
   ```bash
   mix llm_ingest --help
   ```

## Configuration

### Feature Profiles

Create a `llm_features.exs` file in your project root to define feature-specific configurations:

```elixir
%{
  "auth" => %{
    include: "lib/auth/**,test/auth/**,priv/repo/migrations/*_auth_*",
    exclude: "**/*_test.exs"
  },
  "api" => %{
    include: "lib/api/**,lib/schemas/**,test/api/**,lib/*_web/controllers/**",
    exclude: "lib/api/legacy/**"
  },
  "frontend" => %{
    include: "assets/**,lib/*_web/**,test/*_web/**"
  },
  "payments" => %{
    include: "lib/payments/**,lib/billing/**,test/payments/**",
    exclude: "lib/payments/legacy/**,**/*_test.exs"
  },
  "core" => %{
    include: "lib/core/**,lib/application.ex,mix.exs"
  }
}
```

### Pattern Syntax

The task supports glob-style patterns:

- `**` - Matches any number of directories (recursive)
- `*` - Matches any characters except `/`
- `lib/auth/**` - Matches all files under lib/auth/ recursively
- `*.ex` - Matches all .ex files
- `**/*_test.exs` - Matches all test files recursively

## Usage

### Basic Commands

```bash
# Generate ingest file for entire project
mix llm_ingest

# Use a predefined feature configuration
mix llm_ingest --feature=auth

# Custom include patterns
mix llm_ingest --include="lib/specific/**,test/specific/**"

# Custom exclude patterns
mix llm_ingest --exclude="lib/legacy/**,**/*_old.ex"

# Custom output file
mix llm_ingest --output=my-analysis.md

# Disable gitignore integration
mix llm_ingest --no-gitignore

# Specify different root directory
mix llm_ingest /path/to/project --feature=auth
```

### Advanced Usage

```bash
# Combine feature with additional excludes
mix llm_ingest --feature=auth --exclude="**/old_auth.ex"

# Override feature output location
mix llm_ingest --feature=payments --output=analysis/payments-deep-dive.md

# Multiple include patterns
mix llm_ingest --include="lib/auth/**,lib/user/**,config/auth.exs"
```

## Output Structure

The generated markdown file contains:

### 1. Project Header
```markdown
# ProjectName
Project description from mix.exs

---

## Project Structure
```
ASCII tree showing filtered files and directories
```

---

## Files

---

### path/to/file.ex
```elixir
# File contents with syntax highlighting
```

### 2. File Organization

- Files are organized by relative path from project root
- Each file gets its own section with appropriate syntax highlighting
- Supported languages: Elixir, JavaScript, TypeScript, Python, Ruby, Go, Rust, Java, C/C++, CSS, HTML, JSON, YAML, SQL, Bash, Markdown

### 3. Output Location

- Default: `doc/llm-ingest.md`
- With feature: `doc/llm-ingest-{feature}.md`
- Custom: Specify with `--output` flag

## Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--feature` | Use predefined feature configuration | `--feature=auth` |
| `--include` | Include files matching patterns (comma-separated) | `--include="lib/auth/**,test/auth/**"` |
| `--exclude` | Exclude files matching patterns (comma-separated) | `--exclude="**/*_test.exs,lib/legacy/**"` |
| `--output` | Specify output file path | `--output=analysis/deep-dive.md` |
| `--no-gitignore` | Disable automatic gitignore integration | `--no-gitignore` |

## Default Exclusions

The task automatically excludes common non-source files:

- **Version Control**: `.git/`
- **Build Artifacts**: `_build/`, `deps/`, `node_modules/`, `*.beam`
- **Lock Files**: `mix.lock`, `package-lock.json`, `yarn.lock`
- **System Files**: `.DS_Store`, `Thumbs.db`
- **Editor Files**: `.idea/`, `.vscode/`, `*.swp`
- **Generated Docs**: `doc/llm-ingest*.md`

## Examples

### Working on Authentication Feature

1. Create feature configuration:
   ```elixir
   # llm_features.exs
   %{
     "auth" => %{
       include: "lib/auth/**,test/auth/**,lib/*_web/controllers/auth_controller.ex",
       exclude: "**/*_test.exs"
     }
   }
   ```

2. Generate focused ingest file:
   ```bash
   mix llm_ingest --feature=auth
   ```

3. Output: `doc/llm-ingest-auth.md` with only authentication-related files

### API Development

```bash
# Focus on API endpoints and schemas
mix llm_ingest --include="lib/api/**,lib/schemas/**,lib/*_web/controllers/api/**"
```

### Full Project Analysis

```bash
# Include everything except tests and build artifacts
mix llm_ingest --exclude="test/**,**/*_test.exs"
```

## Gitignore Integration

Add this to your `.gitignore` to avoid committing generated files:

```gitignore
# LLM ingest files
doc/llm-ingest*.md
```

## Best Practices

### 1. Feature-Driven Development
- Create specific features for different areas of your codebase
- Use descriptive feature names (`auth`, `payments`, `api`, `frontend`)
- Include related test files and migrations in features

### 2. Pattern Design
- Use `**` for recursive directory matching
- Be specific with include patterns to reduce noise
- Use exclude patterns to remove legacy or deprecated code

### 3. LLM Interaction
- Generate focused ingest files for specific tasks
- Include relevant test files to provide context
- Use feature-specific files to avoid overwhelming the LLM

### 4. Team Collaboration
- Commit `llm_features.exs` to share configurations
- Document feature purposes in team wiki
- Use consistent naming conventions

## Troubleshooting

### Empty Output
- Ensure include patterns match actual file paths
- Check that files aren't being excluded by default patterns
- Verify feature configuration syntax in `llm_features.exs`

### Permission Errors
- Ensure read permissions on source directories
- Check that output directory is writable
- Verify file paths are correct

### Pattern Matching Issues
- Test patterns with simple cases first
- Use forward slashes `/` even on Windows
- Remember that `**` matches directories, `*` matches files

### Large Output Files
- Use more specific include patterns
- Exclude test files with `**/*_test.exs`
- Consider breaking large features into smaller ones

## Advanced Configuration

### Custom Default Excludes
Modify the `@default_excludes` list in the task file to adjust project-wide exclusions.

### Integration with Other Tools
- Combine with git hooks for automatic documentation
- Use in CI/CD for code analysis
- Integrate with documentation generation workflows

## Contributing

To improve this task:

1. Add new file type syntax highlighting
2. Enhance pattern matching capabilities
3. Add git integration features
4. Improve error handling and user feedback

## License

This Mix task is provided as-is for educational and development purposes. Feel free to modify and distribute according to your project's license.

---

**Optional**

Add a Notes section to the generated markdown file to provide context for AI analysis.

Example

# dia
Distributed Intelligent Agents

---

## Feature: agent

**Include patterns:** `lib/dia/application.ex`, `lib/dia/agent/**`, `lib/dia/llm/**`

**Exclude patterns:** `**/*_test.exs`

---

## Notes for AI Analysis

**Agent Feature Context:**
- Look for `GenServer`, `Agent`, or `Task` implementations for stateful processes
- Check for supervision trees in application.ex or dedicated supervisors
- Agent modules typically handle state management and async operations
- Pay attention to process lifecycle, message passing, and error handling

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

---

## Project Structure
...