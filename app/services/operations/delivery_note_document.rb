# frozen_string_literal: true

module Operations
  # Shared assigns for stops/delivery_note — used by UI print and export PDF.
  class DeliveryNoteDocument
    def self.assigns(operation_stop, embed_logo: false, resize_images: true)
      new(operation_stop, embed_logo: embed_logo, resize_images: resize_images).assigns
    end

    def initialize(operation_stop, embed_logo: false, resize_images: true)
      @operation_stop = operation_stop
      @embed_logo = embed_logo
      @resize_images = resize_images
      @customer = operation_stop.operation_route.operation.customer
    end

    def assigns
      source = live_stop
      payload = source ? assigns_from_live(source) : assigns_from_snapshots
      payload[:company_logo_url] = PrintImages.company_logo_data_uri(@customer) if @embed_logo
      payload
    end

    private

    def live_stop
      source = @operation_stop.stop
      source.is_a?(StopVisit) ? source : nil
    end

    def assigns_from_live(source)
      # Read associations from the preloaded source before dup (dup does not copy them).
      visit = source.visit
      destination = visit.destination
      route = source.route
      planning = route&.planning

      stop = source.dup
      stop.custom_attributes = merged_stop_attributes(source)
      # Operation cursor is authoritative once the stop is treated in the field.
      stop.status_updated_at = @operation_stop.status_updated_at if @operation_stop.status_updated_at.present?

      {
        operation_stop: @operation_stop,
        stop: stop,
        visit: visit,
        destination: destination,
        route: route,
        planning: planning,
        customer: @customer,
        photos: photos,
        signature: signature
      }
    end

    def assigns_from_snapshots
      place = @operation_stop.destination_snapshot.presence || {}
      visit_snap = @operation_stop.visit_snapshot || {}
      destination = SnapshotRecord.new(
        place.merge(
          'ref' => place['ref'],
          'customer' => @customer
        )
      )
      visit = SnapshotRecord.new(
        visit_snap.merge(
          'ref' => visit_snap['ref'],
          'destination' => destination,
          'customer' => @customer,
          'default_quantities?' => false
        )
      )
      stop = SnapshotRecord.new(
        'status_updated_at' => @operation_stop.status_updated_at,
        'custom_attributes' => merged_stop_attributes(nil),
        'order' => nil,
        'customer' => @customer
      )

      {
        operation_stop: @operation_stop,
        stop: stop,
        visit: visit,
        destination: destination,
        route: nil,
        planning: nil,
        customer: @customer,
        photos: photos,
        signature: signature
      }
    end

    def merged_stop_attributes(source)
      merged = (source&.custom_attributes || {}).dup
      [@operation_stop.stop_snapshot&.[]('custom_attributes'), @operation_stop.custom_attributes].each do |bag|
        (bag || {}).each { |key, value| merged[key] = value if value.present? }
      end
      merged
    end

    def photos
      @operation_stop.photos.map { |photo| PrintImages.embedded(photo, resize: @resize_images) }
    end

    def signature
      return unless @operation_stop.signature.attached?

      PrintImages.embedded(@operation_stop.signature, resize: @resize_images)
    end

    # Minimal stand-in when the live planning stop was wiped; responds like AR for the BL view.
    class SnapshotRecord
      def initialize(attrs = {})
        @attrs = attrs.stringify_keys
      end

      def custom_attributes
        @attrs['custom_attributes'] || {}
      end

      def custom_attributes_typed_hash(related_field: nil)
        custom_attributes
      end

      def default_quantities?
        !!@attrs['default_quantities?']
      end

      def method_missing(name, *args)
        key = name.to_s
        return @attrs[key] if @attrs.key?(key)
        return !@attrs[key.chomp('?')].nil? if key.end_with?('?') && args.empty?

        super
      end

      def respond_to_missing?(name, include_private = false)
        key = name.to_s
        @attrs.key?(key) || (key.end_with?('?') && @attrs.key?(key.chomp('?'))) || super
      end
    end
  end
end
