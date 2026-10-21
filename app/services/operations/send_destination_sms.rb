# frozen_string_literal: true

module Operations
  class SendDestinationSms
    def self.call(operation:, trackings: nil)
      return 0 unless operation.open?

      customer = operation.customer
      return 0 unless customer.enable_sms_destination

      messaging = SendDriverSms.messaging_service(customer)
      template = customer.sms_template || I18n.t('notifications.sms.alert_plan')
      date = operation.date || Time.zone.today
      list = Array(trackings || operation.operation_delivery_trackings.with_destination)
      OperationDeliveryTracking.preload_visit_stops!(list)

      list.count { |tracking|
        stop = first_visit_stop(tracking)
        phone = phone_for(tracking, stop)
        url = TrackingUrl.for(tracking)
        next false if phone.blank? || url.blank?

        content = replacements(stop, date, url)
        message_id = "#{messaging.class.name.demodulize}c#{customer.id}odt#{tracking.id}t#{date}C"
        sent = messaging.send_message(
          phone,
          messaging.content(template, replacements: content, truncate: !customer.sms_concat),
          country: customer.default_country,
          message_id: message_id,
          from: customer.effective_sms_sender_name
        )
        record_notification!(stop, channel: 'sms', to: phone) if sent
        sent
      }
    end

    def self.first_visit_stop(tracking)
      tracking.visit_stops.first
    end

    def self.phone_for(tracking, stop)
      stop&.destination_snapshot&.[]('phone_number').presence || tracking.destination&.phone_number
    end

    # Timeline-only: do not move the operational status cursor.
    def self.record_notification!(stop, channel:, to:)
      return unless stop

      OperationStops::RecordStatus.call(
        operation_stop: stop,
        status: channel == 'sms' ? 'sms_sent' : 'email_sent',
        recorded_at: Time.current,
        source: 'backoffice',
        update_cursor: false,
        payload: { 'channel' => channel, 'to' => to }
      )
    end

    def self.replacements(stop, date, url)
      snap = stop&.destination_snapshot || {}
      visit = stop&.visit_snapshot || {}
      route = stop&.operation_route
      {
        name: snap['name'],
        ref: snap['ref'],
        visit_ref: visit['ref'],
        street: snap['street'],
        city: snap['city'],
        comment: snap['comment'],
        quantities: quantities_text(stop),
        vehicle_name: route&.vehicle_name,
        phone_number: route&.driver_phone,
        date: I18n.l(date, format: :weekday),
        time: stop&.planned_at || date.beginning_of_day,
        url: url
      }
    end

    # Same net quantity format as PlanningsHelperApi#send_sms_route (VisitQuantities :quantity).
    def self.quantities_text(stop)
      return '' unless stop

      stop.quantity_lines.group_by { |line| line[:unit_id].to_s }.filter_map { |_unit_id, lines|
        pickup = lines.find { |line| line[:kind] == 'pickups' }&.fetch(:value, 0).to_f
        delivery = lines.find { |line| line[:kind] == 'deliveries' }&.fetch(:value, 0).to_f
        next if pickup.zero? && delivery.zero?

        delivery - pickup
      }.join(' ')
    end
    private_class_method :quantities_text
  end
end
