# frozen_string_literal: true

class DestinationMailer < ApplicationMailer
  layout false

  def delivery_tracking(customer:, email:, body:, tracking_url:)
    @customer = customer
    @reseller = customer.reseller
    @body = body
    @tracking_url = tracking_url
    @shipper_name = customer.company_name.presence || customer.name
    @logo_url = customer.company_logo.url.presence
    I18n.with_locale(customer.users.first&.locale || I18n.default_locale) do
      mail to: email.split(/\s*,\s*|\s*;\s*|\s+/),
           subject: t('destination_mailer.delivery_tracking.subject', shipper: @shipper_name)
    end
  end
end
