# frozen_string_literal: true

module Operations
  class SendDestinationEmail
    def self.call(operation:, trackings: nil)
      customer = operation.customer
      template = customer.recipient_template || I18n.t('notifications.email.alert_plan')
      date = operation.date || Time.zone.today
      list = Array(trackings || operation.operation_delivery_trackings.with_destination)
      OperationDeliveryTracking.preload_visit_stops!(list)

      list.count { |tracking|
        stop = SendDestinationSms.first_visit_stop(tracking)
        email = email_for(tracking, stop)
        url = TrackingUrl.for(tracking)
        next false if email.blank? || url.blank?

        body = MessagingService.new(customer.reseller, customer: customer)
                               .content(template, replacements: SendDestinationSms.replacements(stop, date, url), truncate: false)
        DestinationMailer.delivery_tracking(
          customer: customer,
          email: email,
          body: body,
          tracking_url: url
        ).deliver_now
        true
      }
    end

    def self.email_for(tracking, stop)
      stop&.destination_snapshot&.[]('email').presence || tracking.destination&.email
    end
  end
end
