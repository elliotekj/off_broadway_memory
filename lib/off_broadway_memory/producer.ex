defmodule OffBroadwayMemory.Producer do
  @moduledoc """
  A Broadway producer for `OffBroadwayMemory.Buffer`.

  ## Options

  #{NimbleOptions.docs(OffBroadwayMemory.Options.definition())}

  ## Example

  ```
  # Start a buffer:
  OffBroadwayMemory.Buffer.start_link(name: :example_buffer)

  # Connect it to Broadway:
  Broadway.start_link(MyBroadway,
    name: MyBroadway,
    producer: [
      module: {OffBroadwayMemory.Producer, buffer: :example_buffer},
      concurrency: 1
    ],
    processors: [default: [concurrency: 50]]
  )

  # Push data to be processed:
  OffBroadwayMemory.Buffer.push(:example_buffer, ["example", "data", "set"])
  ```

  ## Telemetry

  This library exposes the following Telemetry events:

  * `[:off_broadway_memory, :receive_messages, :start]` - Emitted before receiving messages from the buffer

      * Measurement:

      ```
      %{
        # The current system time in native units from
        # calling: erlang:system_time()
        system_time => integer(),
        monotonic_time => integer(),
      }
      ```

      * Metadata:

      ```
      %{
        name: atom(),
        demand: integer()
      }
      ```

  * `[:off_broadway_memory, :receive_messages, :stop]` - Emitted after messages have been received from the buffer and wrapped

      * Mesurement:

      ```
      %{
        # The current monotonic time minus the start monotonic time in native units
        # by calling: erlang:monotonic_time() - start_monotonic_time
        duration => integer(),
        monotonic_time => integer()
      }
      ```

      * Metadata:

      ```
      %{
        name: atom(),
        messages: [Broadway.Message.t()],
        demand: integer()
      }
      ```
  """

  use GenStage
  @behaviour Broadway.Producer
  @behaviour Broadway.Acknowledger

  alias OffBroadwayMemory.{Buffer, Options}
  alias NimbleOptions.ValidationError

  @doc false
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    case NimbleOptions.validate(opts, Options.definition()) do
      {:ok, opts} ->
        ack_ref = opts[:broadway][:name]
        buffer = opts[:buffer] || opts[:buffer_pid]

        if buffer == nil do
          raise ArgumentError,
                "invalid configuration given to OffBroadwayMemory.Producer.init/1, required :buffer option not found, received options: #{inspect(opts)}"
        end

        resolve_pending_timeout = opts[:resolve_pending_timeout]
        on_failure = opts[:on_failure]

        :persistent_term.put(ack_ref, %{buffer: buffer, on_failure: on_failure})

        state = %{
          buffer: buffer,
          ack_ref: ack_ref,
          demand: 0,
          resolve_pending_timeout: resolve_pending_timeout
        }

        Process.send_after(self(), :resolve_pending, resolve_pending_timeout)

        {:producer, state}

      {:error, error} ->
        raise ArgumentError, format_error(error)
    end
  end

  @impl Broadway.Acknowledger
  def ack(ack_ref, _successful, failed) do
    ack_options = :persistent_term.get(ack_ref)
    requeue? = ack_options[:on_failure] == :requeue

    requeue =
      failed
      |> Enum.reject(&ack?(&1, requeue?))
      |> Enum.map(&get_initial_data(&1))

    Buffer.push(ack_options.buffer, requeue)

    :ok
  end

  @impl Broadway.Acknowledger
  def configure(_ack_ref, ack_data, options) do
    {:ok, Map.merge(ack_data, Map.new(options))}
  end

  @impl true
  def handle_demand(demand, state) do
    {items, state} = resolve_demand(demand, state)
    {:noreply, items, state}
  end

  @impl true
  def handle_info(:resolve_pending, state) do
    {items, state} = resolve_demand(state)
    Process.send_after(self(), :resolve_pending, state.resolve_pending_timeout)
    {:noreply, items, state}
  end

  defp resolve_demand(new_demand \\ 0, %{demand: pending_demand} = state) do
    demand = new_demand + pending_demand
    metadata = %{name: state.ack_ref, demand: demand}

    items =
      :telemetry.span([:off_broadway_memory, :receive_messages], metadata, fn ->
        messages = Buffer.pop(state.buffer, demand) |> transform_messages(state.ack_ref)
        {messages, Map.put(metadata, :messages, messages)}
      end)

    {items, %{state | demand: demand - length(items)}}
  end

  defp transform_messages(messages, ack_ref) do
    Enum.map(messages, &transform_message(&1, ack_ref))
  end

  defp transform_message(message, ack_ref) do
    %Broadway.Message{
      data: message,
      acknowledger: {__MODULE__, ack_ref, %{initial_data: message}}
    }
  end

  defp get_initial_data(message) do
    {_, _, %{initial_data: initial_data}} = message.acknowledger
    initial_data
  end

  defp format_error(%ValidationError{keys_path: [], message: message}) do
    "invalid configuration given to OffBroadwayMemory.Producer.init/1, " <> message
  end

  defp format_error(%ValidationError{keys_path: keys_path, message: message}) do
    "invalid configuration given to OffBroadwayMemory.Producer.init/1 for key #{inspect(keys_path)}, " <>
      message
  end

  defp ack?(%Broadway.Message{} = message, requeue_default) do
    {_, _, message_ack_options} = message.acknowledger
    on_failure = message_ack_options[:on_failure]

    cond do
      on_failure == :requeue -> false
      on_failure != nil -> true
      requeue_default == true -> false
      true -> true
    end
  end
end
