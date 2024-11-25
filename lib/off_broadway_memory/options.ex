defmodule OffBroadwayMemory.Options do
  @moduledoc false

  def definition do
    [
      buffer: [
        # TODO Require this once we drop support for `:buffer_pid`
        type: {:or, [:pid, :atom]},
        doc: """
        The buffer responsible for storing the queued messages. The buffer can
        be supervised independently or by Broadway's supervision tree. To
        supervise the buffer independently, start it before starting Broadway.
        """
      ],
      resolve_pending_timeout: [
        required: false,
        default: 100,
        type: :non_neg_integer,
        doc: """
        The duration (in milliseconds) of the timeout period observed between
        attempts to resolve any pending demand.
        """
      ],
      on_failure: [
        required: false,
        default: :requeue,
        type: :atom,
        doc: """
        The action to perform on failed messages. Options are `:requeue` and
        `:discard`. This can also be configured on a per-message basis with
        `Broadway.Message.configure_ack/2`.
        """
      ],
      broadway: [
        required: true,
        doc: false
      ],
      buffer_pid: [
        type: :pid,
        deprecated: "Renamed to `buffer` in v1.1.0.",
        doc: """
        The buffer responsible for storing the queued messages.
        """
      ]
    ]
  end
end
