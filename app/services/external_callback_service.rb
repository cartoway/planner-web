class ExternalCallbackService
  class ExternalCallbackError < StandardError; end

  def initialize(url)
    @url = url
  end

  def call
    validate_url
    send_request
  rescue RestClient::Exception
    raise ExternalCallbackError, I18n.t('services.external_callback.fail')
  end

  private

  def validate_url
    raise ExternalCallbackError, I18n.t('services.external_callback.invalid_url') unless valid_url?
  end

  def valid_url?
    uri = URI.parse(@url)
    uri.is_a?(URI::HTTP) && !uri.host.nil?
  rescue URI::InvalidURIError
    false
  end

  def send_request
    RestClient.get(@url, timeout: 10)
  end
end
