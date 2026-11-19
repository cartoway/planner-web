# frozen_string_literal: true

module Operations
  module TrackingUrl
    module_function

    # Absolute long URL (export, email, UI). Prefer this outside SMS.
    def long_for(tracking, reseller: nil)
      return nil unless tracking&.token.present?

      reseller ||= tracking.operation.customer.reseller
      "#{reseller.url_protocol}://#{reseller.host}/s/#{tracking.token}"
    end

    # Shortened absolute URL — SMS send only.
    def short_for(tracking, reseller: nil)
      url = long_for(tracking, reseller: reseller)
      return nil unless url

      Rails.application.config.url_shortener.shorten(url)
    end
  end
end
