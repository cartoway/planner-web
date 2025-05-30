class VonageService < MessagingService
  def self.configured?(reseller, service_name = 'vonage')
    super(reseller, service_name)
  end

  def self.definition
    {
      api_key: { field: :text, required: true },
      api_secret: { field: :password, required: true }
    }
  end

  def balance
    config = service_config
    return nil if config['api_key'].blank? || config['api_secret'].blank?

    service = Vonage::Client.new(
      api_key: config['api_key'],
      api_secret: config['api_secret']
    )
    service.account.balance.value
  rescue Vonage::APIError => e
    log_error("SMS balance fetching failed", errors: e.message)
    I18n.t('resellers.form.messagings.credentials_invalid')
  end

  def send_message(to, content, options = {})
    config = service_config

    service = Vonage::Client.new(
      api_key: config['api_key'],
      api_secret: config['api_secret']
    )

    formatted_number = format_phone_number(to, options[:country])
    return false unless formatted_number

    content = I18n.transliterate(content)
    response = service.sms.send(
      from: options[:from] || @reseller.name.gsub(/[^0-9a-z]+/i, '')[0..10],
      to: formatted_number,
      text: content,
      message_id: options[:message_id]
    )

    success = response.messages.all? { |message| message.status == '0' }

    if success
      create_message_log(to, content, message_id: options[:message_id])
      log_success(options[:message_id], response.messages.first)
    else
      log_error(options[:message_id], response.messages.first)
    end

    success
  end

  private

  def log_success(message_id, message)
    return unless @options[:logger]

    @options[:logger].info(
      "Sent SMS\t#{message_id}\t#{message.message_id}\t#{message.message_price}"
    )
  end

  def log_error(message_id, message)
    return unless @options[:logger]

    @options[:logger].error(
      "SMS error\t#{message_id}\t#{message.error_text}"
    )
  end
end
