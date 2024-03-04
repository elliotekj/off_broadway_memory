defmodule OffBroadwayMemory.Options do
  @moduledoc false

  def definition do
    [
      buffer_pid: [
        required: true,
        type: :pid,
        doc: """
        The buffer responsible for storing the queued messages.
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
      ]
    ]
  end
end
