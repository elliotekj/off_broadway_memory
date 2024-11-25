defmodule OffBroadwayMemory.ProducerTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias OffBroadwayMemory.Producer
  alias OffBroadwayMemory.Buffer
  import ExUnit.CaptureLog

  defmodule Forwarder do
    @moduledoc false
    use Broadway

    def handle_message(_, message, %{test_pid: test_pid}) do
      send(test_pid, {:handle_message, message.data})
      message
    end

    def handle_batch(_, messages, _, %{test_pid: test_pid}) do
      send(test_pid, {:handle_batch, Enum.map(messages, & &1.data)})
      messages
    end
  end

  defmodule BuggyForwarder do
    @moduledoc false
    use Broadway

    def handle_message(_, message, %{test_pid: test_pid}) do
      pid_string = inspect(test_pid)

      if :persistent_term.get(pid_string, false) do
        send(test_pid, {:handle_message, message.data})
        message
      else
        :persistent_term.put(pid_string, true)

        message
        |> Broadway.Message.update_data(fn _ -> "bar" end)
        |> Broadway.Message.failed("test failure")
      end
    end

    def handle_batch(_, messages, _, %{test_pid: test_pid}) do
      send(test_pid, {:handle_batch, Enum.map(messages, & &1.data)})
      messages
    end
  end

  describe "init/1 validation" do
    test "requires a buffer" do
      {:error, error} =
        start_supervised({Producer, [broadway: %{name: :test}]}, restart: :temporary)

      argument_error = error |> elem(0) |> elem(0)

      assert argument_error == %ArgumentError{
               message:
                 "invalid configuration given to OffBroadwayMemory.Producer.init/1, required :buffer option not found, received options: [on_failure: :requeue, resolve_pending_timeout: 100, broadway: %{name: :test}]"
             }
    end
  end

  test "receives messages with deprecated :buffer_pid option" do
    {:ok, buffer_pid} = Buffer.start_link()
    {:ok, broadway_pid} = start_broadway(buffer_pid: buffer_pid, resolve_pending_timeout: 50)

    deliver_messages(buffer_pid, 1..2)

    assert_receive {:handle_message, 1}
    assert_receive {:handle_message, 2}
    assert_receive {:handle_batch, [1, 2]}

    stop_broadway(broadway_pid)
  end

  test "receives messages from an externally supervised buffer" do
    Buffer.start_link(name: :test_buffer)
    {:ok, broadway_pid} = start_broadway(buffer: :test_buffer, resolve_pending_timeout: 50)

    deliver_messages(:test_buffer, 1..2)

    assert_receive {:handle_message, 1}
    assert_receive {:handle_message, 2}
    assert_receive {:handle_batch, [1, 2]}

    stop_broadway(broadway_pid)
  end

  test "receives messages from an internally supervised buffer" do
    {:ok, broadway_pid} = start_broadway(buffer: :test_buffer, resolve_pending_timeout: 50)

    deliver_messages(:test_buffer, 1..2)

    assert_receive {:handle_message, 1}
    assert_receive {:handle_message, 2}
    assert_receive {:handle_batch, [1, 2]}

    stop_broadway(broadway_pid)
  end

  test "receives messages when the queue has less than the demand" do
    {:ok, buffer_pid} = Buffer.start_link()
    {:ok, broadway_pid} = start_broadway(buffer: buffer_pid, resolve_pending_timeout: 50)

    deliver_messages(buffer_pid, 1..2)

    assert_receive {:handle_message, 1}
    assert_receive {:handle_message, 2}
    assert_receive {:handle_batch, [1, 2]}

    stop_broadway(broadway_pid)
  end

  test "continues receiving messages when the queue has more than the demand" do
    {:ok, buffer_pid} = Buffer.start_link()
    {:ok, broadway_pid} = start_broadway(buffer: buffer_pid, resolve_pending_timeout: 50)

    deliver_messages(buffer_pid, 1..20)

    for msg <- 1..10 do
      assert_receive {:handle_message, ^msg}
    end

    batch_messages = Enum.to_list(1..10)
    assert_receive {:handle_batch, ^batch_messages}

    for msg <- 11..20 do
      assert_receive {:handle_message, ^msg}
    end

    batch_messages = Enum.to_list(11..20)
    assert_receive {:handle_batch, ^batch_messages}

    stop_broadway(broadway_pid)
  end

  test "continues trying to receive messages when the queue is empty" do
    {:ok, buffer_pid} = Buffer.start_link()
    {:ok, broadway_pid} = start_broadway(buffer: buffer_pid, resolve_pending_timeout: 50)

    deliver_messages(buffer_pid, 1..2)

    assert_receive {:handle_message, 1}
    assert_receive {:handle_message, 2}
    assert_receive {:handle_batch, [1, 2]}

    refute_receive {:handle_message, _}

    deliver_messages(buffer_pid, 3..4)

    assert_receive {:handle_message, 3}
    assert_receive {:handle_message, 4}
    assert_receive {:handle_batch, [3, 4]}

    stop_broadway(broadway_pid)
  end

  test "emits a telemetry start event with demand" do
    self = self()
    {:ok, buffer_pid} = Buffer.start_link()
    {:ok, broadway_pid} = start_broadway(buffer: buffer_pid, resolve_pending_timeout: 50)

    capture_log(fn ->
      :ok =
        :telemetry.attach(
          "start_test",
          [:off_broadway_memory, :receive_messages, :start],
          fn name, measurements, metadata, _ ->
            send(self, {:telemetry_event, name, measurements, metadata})
          end,
          nil
        )
    end)

    deliver_messages(buffer_pid, 1..2)

    assert_receive {:telemetry_event, [:off_broadway_memory, :receive_messages, :start],
                    %{monotonic_time: _}, %{demand: 10}}

    stop_broadway(broadway_pid)
  end

  test "emits a telemetry stop event with messages" do
    self = self()
    {:ok, buffer_pid} = Buffer.start_link()
    {:ok, broadway_pid} = start_broadway(buffer: buffer_pid, resolve_pending_timeout: 50)

    capture_log(fn ->
      :ok =
        :telemetry.attach(
          "stop_test",
          [:off_broadway_memory, :receive_messages, :stop],
          fn name, measurements, metadata, _ ->
            send(self, {:telemetry_event, name, measurements, metadata})
          end,
          nil
        )
    end)

    deliver_messages(buffer_pid, 1..2)

    assert_receive {:telemetry_event, [:off_broadway_memory, :receive_messages, :stop],
                    %{duration: _},
                    %{
                      messages: [%Broadway.Message{data: 1}, %Broadway.Message{data: 2}],
                      demand: _
                    }}

    stop_broadway(broadway_pid)
  end

  test "requeues messages with their original data" do
    Buffer.start_link(name: :test_buffer)
    broadway_opts = [buffer: :test_buffer, resolve_pending_timeout: 25, on_failure: :requeue]
    {:ok, broadway_pid} = start_broadway(broadway_opts, BuggyForwarder)

    deliver_messages(:test_buffer, ["foo"])

    assert_receive {:handle_message, "foo"}

    stop_broadway(broadway_pid)
  end

  test "discards failed messages" do
    Buffer.start_link(name: :test_buffer)
    broadway_opts = [buffer: :test_buffer, resolve_pending_timeout: 25, on_failure: :discard]
    {:ok, broadway_pid} = start_broadway(broadway_opts, BuggyForwarder)

    deliver_messages(:test_buffer, ["foo"])

    refute_receive {:handle_message, _}

    stop_broadway(broadway_pid)
  end

  defp start_broadway(opts, module \\ Forwarder) do
    Broadway.start_link(module,
      name: new_unique_name(),
      context: %{test_pid: self()},
      producer: [
        module: {OffBroadwayMemory.Producer, opts},
        concurrency: 1
      ],
      processors: [default: [concurrency: 1]],
      batchers: [default: [batch_size: 10, batch_timeout: 50, concurrency: 1]]
    )
  end

  defp stop_broadway(broadway_pid) do
    ref = Process.monitor(broadway_pid)
    Process.exit(broadway_pid, :normal)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      1000 -> flunk("Broadway did not stop within 1000ms")
    end
  end

  defp new_unique_name do
    :"BroadwayTest#{System.unique_integer([:positive, :monotonic])}"
  end

  defp deliver_messages(buffer_pid, range) do
    Enum.each(range, fn i -> Buffer.push(buffer_pid, i) end)
  end
end
