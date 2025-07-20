# 🧠 Adding a New Agent to DIA

This guide walks you through adding a new agent module to the `DIA.Agent` system, fully integrated with MCP-style tooling and OpenAI-compatible LLM function calling.

---

## ✅ Overview

In this example, we'll add a new agent called `DIA.Agent.WorkflowPlanner` with a single function `:plan`, which generates a step-by-step plan for a high-level goal.

---

## 🧱 Steps to Add a New Agent

### 1. Define the Agent Module

Create `lib/dia/agent/workflow_planner.ex`:

```elixir
defmodule DIA.Agent.WorkflowPlanner do
  @moduledoc "Plans a sequence of tasks for a given high-level goal."

  @behaviour DIA.Agent.Tool

  use GenServer, restart: :transient
  use DIA.Agent.Describable, type: :workflow_planner

  require Logger

  @timeout 60_000
  @registry DIA.Agent.Registry

  @impl true
  def start_link(%{reg_key: reg_key} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(reg_key))
  end

  defp via_tuple(key), do: {:via, Registry, {@registry, key}}

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state, @timeout}
  end

  @impl true
  def handle_info(:timeout, state), do: {:stop, :normal, state}

  @impl true
  def terminate(reason, %{reg_key: key}) do
    Logger.info("Terminating WorkflowPlanner #{inspect(key)}: #{inspect(reason)}")
    :ok
  end

  @impl true
  def handle_call({:plan, [%{"goal" => goal}]}, _from, state) do
    steps = plan_for(goal)
    {:reply, {:ok, steps}, state, @timeout}
  end

  defp plan_for(goal) do
    goal
    |> String.downcase()
    |> case do
      "publish a blog post" -> ["draft", "edit", "review", "publish"]
      "make coffee" -> ["boil water", "grind beans", "brew", "pour"]
      _ -> ["analyze", "design", "execute"]
    end
  end
end
````

---

### 2. Register It in the Type Registry

Update `lib/dia/agent/type_registry.ex`:

Add this inside `@agent_types`:

```elixir
workflow_planner: %{
  name: :workflow_planner,
  module: DIA.Agent.WorkflowPlanner,
  description: "Plans a sequence of steps given a high-level goal.",
  functions: %{
    plan: %{
      description: "Generates a step-by-step plan for a user-defined goal.",
      parameters: %{
        type: :object,
        properties: %{
          goal: %{type: :string, description: "A user goal like 'publish a blog post'"}
        },
        required: [:goal]
      },
      returns: %{
        type: :array,
        items: %{type: :string}
      }
    }
  }
}
```

---

### 3. Compile the Project

```bash
mix compile
```

---

### 4. Test via IEx

```elixir
# Call the agent directly
DIA.Agent.dispatch_by_type(:workflow_planner, :plan, [%{"goal" => "make coffee"}], "u1", "s1")
# => {:ok, ["boil water", "grind beans", "brew", "pour"]}

# Call via LLM-compatible function router
DIA.LLM.FunctionRouter.route("workflow_planner:plan", %{"goal" => "make coffee"}, "u1", "s1")
# => {:ok, ["boil water", "grind beans", "brew", "pour"]}

# Export to OpenAI tool spec
IO.puts DIA.LLM.FunctionExporter.to_json()
```

---

### 5. (Optional) Describe the Agent

```elixir
{:ok, pid} = DIA.Agent.resolve_pid(DIA.Agent.WorkflowPlanner, "u1", "s1")
GenServer.call(pid, :describe)
# => metadata from TypeRegistry
```

---

## 📁 Summary

| Component             | Purpose                                           |
| --------------------- | ------------------------------------------------- |
| `workflow_planner.ex` | GenServer agent that implements behavior          |
| `type_registry.ex`    | Declares function metadata and schema             |
| `Describable` macro   | Injects `describe/0` and `handle_call(:describe)` |
| `FunctionExporter`    | Converts metadata to OpenAI-compatible spec       |
| `FunctionRouter`      | Routes LLM calls to actual agents                 |

---

## ✅ Naming Convention

Function names exposed to LLMs are of the form:

```
<agent_type>:<function>
e.g. "workflow_planner:plan"
```

They are parsed and routed by `DIA.LLM.FunctionRouter`.

---

Happy hacking! 🤖



## 🔁 Agent Registration Key Migration Note

### Previous Format:
```elixir
{agent_type, user_id, chat_session_id}
````

### New Format:

```elixir
{agent_type, user_id, chat_session_id, login_session_id}
```

To support tracking **per-device login sessions**, agents now use a structured `DIA.Agent.RegKey` for registration and lookup.

### Benefits:

* Allows multiple devices to run isolated agent processes for the same user
* Enables targeted cleanup, audit, or analytics per login session
* Makes agent keys extensible and self-documenting

### What Changed:

* `reg_key` is now a **struct**: `%DIA.Agent.RegKey{...}`
* It is converted to a 4-element tuple for `Registry` compatibility
* All agent modules receive a `reg_key` that includes `login_session_id` (or `nil` if not provided)
* `DIA.Agent.resolve_pid/4` now accepts optional `login_session_id`

### Backward Compatibility:

If `login_session_id` is not provided, the system still works as before. No immediate changes are required to existing clients unless they wish to scope agents by login session.

### Example:

```elixir
# Previously:
{:ok, pid} = DIA.Agent.resolve_pid(DIA.Agent.QueryParser, "u1", "chat1")

# Now (optional login session ID):
{:ok, pid} = DIA.Agent.resolve_pid(DIA.Agent.QueryParser, "u1", "chat1", "device_42")
```
