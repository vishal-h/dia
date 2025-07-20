defmodule DIA.Agent.Describable do
  @moduledoc """
  Provides a macro that injects:
    - describe/0
    - handle_call(:describe) as a GenServer callback
  based on the given `:type`.
  """

  defmacro __using__(opts) do
    type = Keyword.fetch!(opts, :type)

    quote do
      @impl true
      def describe do
        {:ok, DIA.Agent.TypeRegistry.raw()[unquote(type)]}
      end

      @impl true
      def handle_call(:describe, _from, state) do
        {:ok, meta} = describe()
        {:reply, meta, state, @timeout}
      end
    end
  end
end
