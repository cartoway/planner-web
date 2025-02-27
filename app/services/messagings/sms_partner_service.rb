class SmsPartnerService < MessagingService
  SEND_SMS_URL = 'https://api.smspartner.fr/v1/send'.freeze

  def self.configured?(customer, service_name = 'sms_partner')
    super(customer, service_name)
  end

  def self.definition
    {
      api_key: { field: :text, required: true }
    }
  end

  def send_message(to, content, options = {})
    config = check_service_config

    formatted_number = format_phone_number(to, options[:country])
    return false unless formatted_number

    fitlered_options = {
      apiKey: config['api_key'],
      sender: options[:sender] || @reseller.name,
      gamme: 1,
      isStopSms: false,
      tag: options[:tag] || "c#{@customer.id}"
    }

    response = send_sms(
      formatted_number,
      content,
      **fitlered_options
    )
    response = SmsPartnerResponse.new(parse_response(response))
    if response.success?
      create_message_log(to, content, {
        message_id: options[:message_id],
        raw_data: response.raw_data
      })
      true
    else
      log_error("SMS sending failed", errors: response.errors.join(", "))
      false
    end
  end

  private

  def log_error(message, details = {})
    Rails.logger.error("#{self.class.name} error: #{message}")
    details.each { |k, v| Rails.logger.error("  #{k}: #{v}") }
  end

  def send_sms(to, content, options = {})
    json = {
      phoneNumbers: to,
      message: content,
      **options
    }

    RestClient.post(SEND_SMS_URL, json.to_json, content_type: :json, accept: :json)
  end

  def parse_response(response)
    JSON.parse(response.body)
  end

  class SmsPartnerResponse
    def initialize(body)
      @success    = body['success']
      @errors     = body['error']
      @code       = body['code']
      @message_id = body['message_id']
      @raw_data   = body
    end

    def success?
      @success
    end

    attr_reader :errors, :code, :message_id, :raw_data
  end
end
