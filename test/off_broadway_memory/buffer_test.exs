defmodule OffBroadwayMemory.BufferTest do
  @moduledoc false
  use ExUnit.Case
  alias OffBroadwayMemory.Buffer

  setup do
    {:ok, pid} = Buffer.start_link()
    {:ok, %{buffer_pid: pid}}
  end

  describe "start_link/1" do
    test "uses options" do
      Buffer.start_link(name: :buffer)
      assert :ok == Buffer.push(:buffer, "test")
      assert ["test"] == Buffer.pop(:buffer)
    end
  end

  describe "push/2" do
    test "pushes a message", %{buffer_pid: buffer_pid} do
      assert :ok == Buffer.push(buffer_pid, "test")
    end

    test "pushes a list of messages", %{buffer_pid: buffer_pid} do
      assert :ok == Buffer.push(buffer_pid, ["test 1", "test 2"])
    end
  end

  describe "async_push/2" do
    test "pushes a message", %{buffer_pid: buffer_pid} do
      assert :ok == Buffer.async_push(buffer_pid, "test")
    end

    test "pushes a list of messages", %{buffer_pid: buffer_pid} do
      assert :ok == Buffer.async_push(buffer_pid, ["test 1", "test 2"])
    end
  end

  describe "pop/2" do
    test "pops 1 message by default", %{buffer_pid: buffer_pid} do
      Buffer.push(buffer_pid, ["test 1", "test 2"])
      assert ["test 1"] == Buffer.pop(buffer_pid)
      assert 1 == Buffer.length(buffer_pid)
    end

    test "pops multiple messages", %{buffer_pid: buffer_pid} do
      Buffer.push(buffer_pid, ["test 1", "test 2", "test 3"])
      assert ["test 1", "test 2"] == Buffer.pop(buffer_pid, 2)
      assert 1 == Buffer.length(buffer_pid)
    end

    test "pops an empty buffer", %{buffer_pid: buffer_pid} do
      assert [] == Buffer.pop(buffer_pid, 10)
    end

    test "pops nothing", %{buffer_pid: buffer_pid} do
      Buffer.push(buffer_pid, ["test 1"])
      assert [] == Buffer.pop(buffer_pid, 0)
    end

    test "pops the whole buffer", %{buffer_pid: buffer_pid} do
      Buffer.push(buffer_pid, ["test 1", "test 2", "test 3"])
      assert ["test 1", "test 2", "test 3"] == Buffer.pop(buffer_pid, 3)
      assert 0 == Buffer.length(buffer_pid)
    end
  end

  describe "clear/1" do
    test "clears the buffer", %{buffer_pid: buffer_pid} do
      Buffer.push(buffer_pid, ["test 1", "test 2", "test 3"])
      assert :ok == Buffer.clear(buffer_pid)
      assert 0 == Buffer.length(buffer_pid)
    end
  end

  describe "length/1" do
    test "returns the length for an empty queue", %{buffer_pid: buffer_pid} do
      assert 0 == Buffer.length(buffer_pid)
    end

    test "returns the length for a populated queue", %{buffer_pid: buffer_pid} do
      Buffer.push(buffer_pid, ["test 1", "test 2"])
      assert 2 == Buffer.length(buffer_pid)
    end
  end
end
