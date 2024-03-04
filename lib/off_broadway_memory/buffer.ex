defmodule OffBroadwayMemory.Buffer do
  @moduledoc """
  An in-memory buffer implementation using `:queue`.
  """

  use GenServer

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %{queue: :queue.new()}}
  end

  @doc """
  Push messages to the buffer.
  """
  @spec push(pid(), list(any()) | any()) :: :ok
  def push(pid, messages) do
    GenServer.call(pid, {:push, messages})
  end

  @doc """
  Pop messages from the buffer.
  """
  @spec pop(pid(), non_neg_integer()) :: list(any())
  def pop(pid, count \\ 1) do
    GenServer.call(pid, {:pop, count})
  end

  @doc """
  Clear all messages from the buffer.
  """
  @spec clear(pid()) :: :ok
  def clear(pid) do
    GenServer.call(pid, :clear)
  end

  @doc """
  Get the length of the buffer.
  """
  @spec length(pid()) :: non_neg_integer()
  def length(pid) do
    GenServer.call(pid, :length)
  end

  @impl true
  def handle_call({:push, messages}, _from, state) when is_list(messages) do
    join = :queue.from_list(messages)
    queue = :queue.join(state.queue, join)
    {:reply, :ok, %{state | queue: queue}}
  end

  def handle_call({:push, message}, _from, state) do
    join = :queue.from_list([message])
    queue = :queue.join(state.queue, join)
    {:reply, :ok, %{state | queue: queue}}
  end

  def handle_call({:pop, count}, _from, state) do
    {messages, new_queue} =
      case :queue.len(state.queue) do
        len when len == 0 ->
          {[], state.queue}

        len when len - count <= 0 ->
          {:queue.to_list(state.queue), :queue.new()}

        _len ->
          {messages, queue} = :queue.split(count, state.queue)
          {:queue.to_list(messages), queue}
      end

    {:reply, messages, %{state | queue: new_queue}}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | queue: :queue.new()}}
  end

  def handle_call(:length, _from, state) do
    length = :queue.len(state.queue)
    {:reply, length, state}
  end
end
