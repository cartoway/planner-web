# frozen_string_literal: true

module Operations
  module TrackingUrl
    module_function

    def for(tracking)
      return nil unless tracking&.token.present?

      reseller = tracking.operation.customer.reseller
      path = "/s/#{tracking.token}"
      url = "#{reseller.url_protocol}://#{reseller.host}#{path}"
      Rails.application.config.url_shortener.shorten(url)
    end

    def long_for(tracking)
      return nil unless tracking&.token.present?

      reseller = tracking.operation.customer.reseller
      "#{reseller.url_protocol}://#{reseller.host}/s/#{tracking.token}"
    end
  end
end
