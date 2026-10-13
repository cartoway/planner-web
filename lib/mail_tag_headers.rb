# frozen_string_literal: true

# Maps neutral mail tags to ESP-specific SMTP headers.
module MailTagHeaders
  module_function

  def apply!(message, tags, provider:)
    tags = Array(tags).compact.reject(&:blank?)
    return if tags.empty? || provider.blank?

    case provider.to_sym
    when :brevo
      tags.each { |tag| message.header.add('X-Mailin-Tag', tag) }
    when :mailgun
      tags.each { |tag| message.header.add('X-Mailgun-Tag', tag) }
    when :postmark
      # Postmark accepts a single tag only.
      message.header.add('X-PM-Tag', tags.join('|'))
    when :sendgrid
      message.header.add('X-SMTPAPI', { category: tags }.to_json)
    when :ses
      # SES expects key=value pairs; our tags are already "key:value".
      message.header.add('X-SES-MESSAGE-TAGS', tags.map { |tag| tag.sub(':', '=') }.join(', '))
    else
      raise ArgumentError, "Unknown action_mailer.smtp_provider: #{provider.inspect}"
    end
  end
end
