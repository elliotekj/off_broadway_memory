defmodule OffBroadwayMemory.Buffer do
  @moduledoc """
  An in-memory buffer implementation using `:queue`.
  """

  use GenServer

  @initial_state %{queue: :queue.new(), length: 0}

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, @initial_state}
  end

  @doc """
  Push messages to the buffer.
  """
  @spec push(GenServer.server(), list(any()) | any()) :: :ok
  def push(server, messages) do
    GenServer.call(server, {:push, messages})
  end

  @doc """
  Push messages to the buffer asynchronously.
  """
  @spec async_push(GenServer.server(), list(any()) | any()) :: :ok
  def async_push(server, messages) do
    GenServer.cast(server, {:push, messages})
  end

  @doc """
  Pop messages from the buffer.
  """
  @spec pop(GenServer.server(), non_neg_integer()) :: list(any())
  def pop(server, count \\ 1) do
    GenServer.call(server, {:pop, count})
  end

  @doc """
  Clear all messages from the buffer.
  """
  @spec clear(GenServer.server()) :: :ok
  def clear(server) do
    GenServer.call(server, :clear)
  end

  @doc """
  Get the length of the buffer.
  """
  @spec length(GenServer.server()) :: non_neg_integer()
  def length(server) do
    GenServer.call(server, :length)
  end

  @impl true
  def handle_call({:push, messages}, _from, state) when is_list(messages) do
    state = push_to_state(state, messages)

    {:reply, :ok, state}
  end

  def handle_call({:push, message}, _from, state) do
    updated_queue = :queue.in(message, state.queue)

    {:reply, :ok, %{queue: updated_queue, length: state.length + 1}}
  end

  def handle_call({:pop, _count}, _from, %{length: 0} = state) do
    {:reply, [], state}
  end

  def handle_call({:pop, count}, _from, %{length: length} = state) when count >= length do
    {:reply, :queue.to_list(state.queue), @initial_state}
  end

  def handle_call({:pop, count}, _from, state) do
    {messages, updated_queue} = :queue.split(count, state.queue)

    updated_state = %{
      queue: updated_queue,
      length: state.length - count
    }

    {:reply, :queue.to_list(messages), updated_state}
  end

  def handle_call(:clear, _from, _state) do
    {:reply, :ok, @initial_state}
  end

  def handle_call(:length, _from, %{length: length} = state) do
    {:reply, length, state}
  end

  @impl true
  def handle_cast({:push, messages}, state) when is_list(messages) do
    state = push_to_state(state, messages)

    {:noreply, state}
  end

  def handle_cast({:push, message}, state) do
    updated_queue = :queue.in(message, state.queue)

    {:noreply, %{queue: updated_queue, length: state.length + 1}}
  end

  defp push_to_state(state, messages) do
    messages_length = Kernel.length(messages)

    join = :queue.from_list(messages)
    updated_queue = :queue.join(state.queue, join)

    %{queue: updated_queue, length: state.length + messages_length}
  end
end
