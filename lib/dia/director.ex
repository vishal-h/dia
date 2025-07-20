defmodule DIA.Director do
  @moduledoc """
  Director for managing agents.
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, opts}
  end



end
