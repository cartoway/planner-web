# frozen_string_literal: true

module Operations
  module TrackingUrl
    module_function

    def for(tracking, reseller: nil)
      url = long_for(tracking, reseller: reseller)
      return unless url

      Rails.application.config.url_shortener.shorten(url)
    end

    def long_for(tracking, reseller: nil)
      return nil unless tracking&.token.present?

      reseller ||= tracking.operation.customer.reseller
      "#{reseller.url_protocol}://#{reseller.host}/s/#{tracking.token}"
    end
  end
end
