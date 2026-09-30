# frozen_string_literal: true

module Operations
  class SendDriverSms
    def self.call(operation:, routes:)
      customer = operation.customer
      messaging = messaging_service(customer)
      template = customer.sms_driver_template || I18n.t('notifications.sms.alert_driver')
      date = operation.date || Time.zone.today

      routes.count { |operation_route|
        phone = operation_route.driver_phone
        url = MobileUrl.for(operation_route)
        next false if phone.blank? || url.blank?

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
          from: customer.reseller.name
        )
        operation_route.mark_sent!('sms') if sent
        sent
      }
    end

    def self.messaging_service(customer)
      if VonageService.configured?(customer.reseller)
        VonageService.new(customer.reseller, customer: customer)
      elsif SmsPartnerService.configured?(customer.reseller)
        SmsPartnerService.new(customer.reseller, customer: customer)
      else
        raise ArgumentError, "No SMS service configured for reseller #{customer.reseller_id}"
      end
    end
  end
end
