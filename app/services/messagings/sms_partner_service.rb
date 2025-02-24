class SmsPartnerService < MessagingService
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

    Smspartner.configure do |sms_config|
      sms_config.api_key = config['api_key']
      sms_config.sender = options[:sender] || config['sender']
      sms_config.range_value = options[:range_value] || :premium
    end

    formatted_number = format_phone_number(to, options[:country])
    return false unless formatted_number

    response = Smspartner.send_sms(
      to: formatted_number,
      body: content
    )

    if response.success?
      create_message_log(to, content, {
        message_id: response.message_id,
        cost: response.raw_data['total_cost'],
        nb_sms: response.raw_data['total_sms']
      })
      true
    else
      log_error("SMS sending failed", errors: response.errors.join(", "))
      false
    end
  rescue => e
    log_error("Failed to send SMS", error: e.message)
    false
  end

  private

  def log_error(message, details = {})
    Rails.logger.error("#{self.class.name} error: #{message}")
    details.each { |k, v| Rails.logger.error("  #{k}: #{v}") }
  end
end
