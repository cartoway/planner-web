# frozen_string_literal: true

module Operations
  # Print-styled delivery note PDF for operation export (snapshots + proofs, no live planning graph).
  class DeliveryNotePdf
    def self.call(operation_stop:)
      new(operation_stop).call
    end

    def initialize(operation_stop)
      @operation_stop = operation_stop
    end

    def call
      HtmlToPdf.call(html)
    end

    def html
      ApplicationController.render(
        template: 'stops/delivery_note',
        layout: 'operations/export_delivery_note',
        # Export stays on operation snapshots — no visits/destinations/routes/plannings queries.
        assigns: DeliveryNoteDocument.assigns(
          @operation_stop,
          embed_logo: true,
          snapshots_only: true
        )
      )
    end
  end
end
