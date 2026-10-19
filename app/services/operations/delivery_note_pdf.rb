# frozen_string_literal: true

module Operations
  # Print-styled delivery note PDF — same template/assigns as OperationStopsController#delivery_note.
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
        # Bulk export: skip ActiveStorage variants (avoids N+1 on variant_records).
        assigns: DeliveryNoteDocument.assigns(@operation_stop, embed_logo: true, resize_images: false)
      )
    end
  end
end
