# frozen_string_literal: true

module Operations
  class SendDriverSms
    def self.call(operation:, routes:)
      return 0 unless operation.open?

      customer = operation.customer
      return 0 unless customer.enable_sms_driver

      messaging = messaging_service(customer)
      template = customer.sms_driver_template || I18n.t('notifications.sms.alert_driver')
      date = operation.date || Time.zone.today

      routes.count { |operation_route|
        phone = operation_route.driver_phone
        next false if phone.blank?

        url = MobileUrl.short_for(operation_route)
        next false if url.blank?

        content = {
          route_name: [operation_route.ref, operation_route.vehicle_name].compact.join(' - '),
          date: I18n.l(date, format: :weekday),
          size_active: operation_route.operation_stops.executable.count,
          url: url
        }
        message_id = "#{messaging.class.name.demodulize}c#{customer.id}or#{operation_route.id}t#{date}D"
        sent = messaging.send_message(
          phone,
          messaging.content(template, replacements: content, truncate: !customer.sms_concat),
          country: customer.default_country,
          message_id: message_id,
          from: customer.effective_sms_sender_name
        )
        operation_route.mark_sent!('sms') if sent
        sent
      }
    end

    def self.messaging_service(customer)
      MessagingService.for_customer(customer)
    end
  end
end
