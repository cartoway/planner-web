# frozen_string_literal: true

module Operations
  class SendDestinationSms
    def self.call(operation:, trackings: nil)
      customer = operation.customer
      messaging = SendDriverSms.messaging_service(customer)
      template = customer.sms_template || I18n.t('notifications.sms.alert_plan')
      date = operation.date || Time.zone.today
      list = trackings || operation.operation_delivery_trackings.includes(:destination)

      list.count { |tracking|
        stop = first_visit_stop(tracking)
        phone = phone_for(tracking, stop)
        url = TrackingUrl.for(tracking)
        next false if phone.blank? || url.blank?

        content = replacements(stop, date, url)
        message_id = "#{messaging.class.name.demodulize}c#{customer.id}odt#{tracking.id}t#{date}C"
        messaging.send_message(
          phone,
          messaging.content(template, replacements: content, truncate: !customer.sms_concat),
          country: customer.default_country,
          message_id: message_id,
          from: customer.sms_from_customer_name ? customer.name : customer.reseller.name
        )
      }
    end

    def self.first_visit_stop(tracking)
      tracking.visit_stops.first
    end

    def self.phone_for(tracking, stop)
      stop&.destination_snapshot&.[]('phone_number').presence || tracking.destination&.phone_number
    end

    def self.replacements(stop, date, url)
      snap = stop&.destination_snapshot || {}
      visit = stop&.visit_snapshot || {}
      {
        name: snap['name'],
        ref: snap['ref'],
        visit_ref: visit['ref'],
        street: snap['street'],
        city: snap['city'],
        comment: snap['comment'],
        date: I18n.l(date, format: :weekday),
        time: stop&.planned_at || date.beginning_of_day,
        url: url
      }
    end
  end
end
