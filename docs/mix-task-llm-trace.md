# Mix Task: LLM Trace - Usage Documentation

A powerful Mix task for automatically discovering code dependencies and generating LLM-friendly feature configurations. This tool traces function calls and module dependencies to create focused code ingestion files for AI-assisted development.

## 🚀 Quick Start

### Basic Usage
```bash
# Trace from a specific function
mix llm_trace DIA.LLM.FunctionRouter.route/4 --name=query_parser

# Use verbose output for debugging
mix llm_trace DIA.LLM.FunctionRouter.route/4 --name=query_parser --verbose
```

### Output
Creates `llm_features_traced.exs` with auto-discovered dependencies:
```elixir
%{
  "query_parser" => %{
    include: "lib/dia/agent.ex,lib/dia/llm/function_router.ex,lib/dia/agent/type_registry.ex",
    exclude: "**/*_test.exs",
    description: "Auto-generated from code tracing query_parser"
  }
}
```

## 📋 Command Line Options

| Option | Description | Example | Default |
|--------|-------------|---------|---------|
| `--name` | Feature name for the generated configuration | `--name=auth` | Inferred from module |
| `--depth` | How deep to trace dependencies | `--depth=5` | `5` |
| `--output` | Output file path | `--output=my_features.exs` | `llm_features_traced.exs` |
| `--include-tests` | Include test files in patterns | `--include-tests=false` | `true` |
| `--verbose` | Show detailed debug output | `--verbose` | `false` |
| `--runtime` | Use runtime tracing (experimental) | `--runtime` | `false` |

## 🎯 Usage Examples

### 1. Basic Function Tracing
```bash
# Trace a specific function and its dependencies
mix llm_trace MyApp.Auth.login/2 --name=authentication

# Result: Discovers all modules that Auth.login/2 depends on
```

### 2. Deep Dependency Analysis
```bash
# Trace deeper into the dependency chain
mix llm_trace MyApp.Payments.process/3 --name=payments --depth=7

# Result: Finds not just direct dependencies, but dependencies of dependencies
```

### 3. Custom Output Location
```bash
# Save to a specific file
mix llm_trace MyApp.API.Router.route/3 --name=api --output=features/api_analysis.exs
```

### 4. Exclude Tests
```bash
# Generate config without test files
mix llm_trace MyApp.Core.Service.run/1 --name=core --include-tests=false
```

### 5. Debug Mode
```bash
# See detailed tracing information
mix llm_trace MyApp.LLM.Agent.dispatch/2 --name=agent --verbose
```

## 🔍 How It Works

### 1. **Module Discovery**
- Finds all modules in your application
- Uses compilation metadata and loaded modules
- Automatically compiles project if needed

### 2. **AST Analysis**
- Parses source files to extract module references
- Resolves aliases (`alias DIA.Agent` → `Agent.function()` → `DIA.Agent`)
- Finds `use`, `import`, function calls, and struct usage

### 3. **Dependency Tracing**
- Recursively traces module dependencies
- Builds complete dependency graph
- Respects depth limits to avoid infinite loops

### 4. **Pattern Generation**
- Converts modules to file patterns
- Includes both source files and tests
- Generates comma-separated include patterns

## 📁 Output Structure

### Generated Configuration
```elixir
%{
  "feature_name" => %{
    include: "lib/module1.ex,lib/module2.ex,lib/subdir/module3.ex",
    exclude: "**/*_test.exs",
    description: "Auto-generated from code tracing feature_name"
  }
}
```

### Integration with LLM Ingest
Use the generated config with your main LLM ingest task:
```bash
# Copy generated features to main config
cp llm_features_traced.exs llm_features.exs

# Use with LLM ingest
mix llm_ingest --feature=feature_name
```

## 🛠️ Advanced Usage

### Combining with Manual Configurations
```elixir
# Your existing llm_features.exs
%{
  "manual_feature" => %{
    include: "lib/specific/**",
    exclude: "lib/specific/legacy/**"
  }
}

# After running llm_trace, merge configs:
%{
  "manual_feature" => %{
    include: "lib/specific/**",
    exclude: "lib/specific/legacy/**"
  },
  "auto_discovered" => %{
    include: "lib/auto/discovered.ex,lib/other/module.ex",
    exclude: "**/*_test.exs",
    description: "Auto-generated from code tracing"
  }
}
```

### Iterative Development Workflow
```bash
# 1. Discover initial dependencies
mix llm_trace MyApp.Feature.main/1 --name=new_feature

# 2. Review and refine
mix llm_ingest --feature=new_feature

# 3. If missing dependencies, trace deeper
mix llm_trace MyApp.Feature.main/1 --name=new_feature --depth=10

# 4. Trace related functions
mix llm_trace MyApp.Feature.helper/2 --name=new_feature_extended
```

## 🔧 Troubleshooting

### Empty or Minimal Output
**Problem**: Generated config has very few files
```bash
# Enable verbose mode to see what's happening
mix llm_trace MyApp.Module.function/1 --name=test --verbose
```

**Common causes**:
- Module not compiled yet → Run `mix compile` first
- Function doesn't exist → Check spelling and arity
- No dependencies found → Module might be very isolated

### Module Not Found Errors
**Problem**: `String.to_existing_atom` errors
```bash
# Check the exact module name
iex> MyApp.Module.function/1  # Verify this works

# Try different module reference
mix llm_trace "MyApp.Module.function/1" --name=test
```

### Alias Resolution Issues
**Problem**: Dependencies not discovered despite being called
```bash
# Use verbose mode to see alias resolution
mix llm_trace MyApp.Module.function/1 --name=test --verbose

# Look for: "Found aliases: %{...}"
# And: "Found call: Alias.function() -> resolved to Full.Module.Name"
```

## 📊 Understanding Output

### Verbose Mode Output
```bash
mix llm_trace MyApp.Module.function/1 --name=test --verbose
```

Shows:
- **Module discovery**: How many modules found
- **Source file discovery**: Which files are being read
- **Alias resolution**: How aliases are mapped
- **Dependency normalization**: Raw → filtered dependencies
- **Pattern generation**: Final file patterns

### Example Verbose Output
```
Tracing feature: test
Starting from: MyApp.Module.function/1
Using static analysis...
Found 18 modules from application key
Working with 18 available modules
Searching for source of MyApp.Module
Found source file, parsing dependencies...
Found aliases: %{Helper: MyApp.Helper}
Found call: Helper.process() -> resolved to MyApp.Helper
Raw dependencies before normalization: [MyApp.Helper, MyApp.Module]
Normalizing MyApp.Helper -> MyApp.Helper
Normalizing MyApp.Module -> MyApp.Module
Final normalized dependencies: [MyApp.Helper, MyApp.Module]
Module MyApp.Module depends on 1 modules
Found 2 related modules using pattern matching
Generated feature 'test' in llm_features_traced.exs
```

## 🎯 Best Practices

### 1. Start with Entry Points
```bash
# Trace from main entry points of your features
mix llm_trace MyApp.AuthController.login/2 --name=auth
mix llm_trace MyApp.PaymentProcessor.charge/3 --name=payments
```

### 2. Use Descriptive Names
```bash
# Good: Descriptive feature names
mix llm_trace MyApp.User.create/1 --name=user_registration
mix llm_trace MyApp.Email.send/2 --name=email_delivery

# Avoid: Generic names
mix llm_trace MyApp.User.create/1 --name=user  # Too broad
```

### 3. Validate Results
```bash
# Always check the generated patterns make sense
mix llm_trace MyApp.Feature.main/1 --name=feature
cat llm_features_traced.exs  # Review output

# Test with LLM ingest to verify
mix llm_ingest --feature=feature
```

### 4. Combine with Manual Configuration
```bash
# Use auto-discovery as a starting point
mix llm_trace MyApp.Complex.process/2 --name=complex_feature

# Then manually refine the generated config
# Add specific edge cases, remove irrelevant files
```

### 5. Document Your Process
```bash
# Keep notes on which functions you traced
echo "# Feature discovery log" > trace_log.md
echo "mix llm_trace MyApp.Auth.login/2 --name=auth --depth=5" >> trace_log.md
echo "Result: Found auth, user, session modules" >> trace_log.md
```

## 🚀 Integration Examples

### With Existing LLM Workflows
```bash
# 1. Discover feature boundaries
mix llm_trace MyApp.NewFeature.main/1 --name=new_feature

# 2. Generate LLM-ready files
mix llm_ingest --feature=new_feature

# 3. Use with your preferred LLM tool
# The generated markdown contains all relevant code for the feature
```

### CI/CD Integration
```bash
# In your CI pipeline, auto-discover changed features
mix llm_trace $(git diff --name-only | grep "\.ex$" | head -1) --name=changed_feature

# Generate documentation for changed code
mix llm_ingest --feature=changed_feature --output=docs/changed_code.md
```

### Team Collaboration
```bash
# Share discovered feature boundaries
mix llm_trace MyApp.ImportantFeature.run/1 --name=important_feature
git add llm_features_traced.exs
git commit -m "Auto-discovered dependencies for important_feature"

# Team members can use the same boundaries
mix llm_ingest --feature=important_feature
```

## 🔮 Future Enhancements

### Coming Soon
- **Runtime tracing**: Trace actual execution paths
- **AI-powered analysis**: Smart feature naming and descriptions
- **Git integration**: Trace based on changed files
- **Interactive mode**: Choose dependencies interactively

### Roadmap
- **Performance optimization**: Faster analysis for large codebases
- **IDE integration**: VS Code extension for one-click tracing
- **Team analytics**: Track most-traced modules across team
- **Dependency visualization**: Generate dependency graphs

---

**Made with ❤️ for smarter AI-assisted development**

*Star this tool if it helps you build better software with AI assistance!*