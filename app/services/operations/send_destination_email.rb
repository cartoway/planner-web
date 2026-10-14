# frozen_string_literal: true

module Operations
  class SendDestinationEmail
    def self.call(operation:, trackings: nil)
      customer = operation.customer
      return 0 unless customer.enable_email_destination

      locale = mail_locale(customer)
      date = operation.date || Time.zone.today
      list = Array(trackings || operation.operation_delivery_trackings.with_destination)
      OperationDeliveryTracking.preload_visit_stops!(list)

      I18n.with_locale(locale) do
        template = customer.recipient_template || I18n.t('notifications.email.alert_plan')
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
            tracking_url: url,
            locale: locale
          ).deliver_now
          SendDestinationSms.record_notification!(stop, channel: 'email', to: email)
          true
        }
      end
    end

    def self.email_for(tracking, stop)
      stop&.destination_snapshot&.[]('email').presence || tracking.destination&.email
    end

    # Prefer a customer user locale; fall back to the current request locale (not default_locale).
    def self.mail_locale(customer)
      customer.users.detect { |user| user.locale.present? }&.locale || I18n.locale
    end
  end
end
