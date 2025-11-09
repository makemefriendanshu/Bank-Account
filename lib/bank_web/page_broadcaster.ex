defmodule BankWeb.PageBroadcaster do
  use GenServer

  @moduledoc """
  GenServer that broadcasts page update events to all LiveViews when data changes.
  """

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Notify all subscribers (LiveViews) to update their data.
  """
  def broadcast_update(topic, payload \\ %{}) do
    Phoenix.PubSub.broadcast(Bank.PubSub, topic, {:page_update, payload})
  end

  # Server Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end
end
