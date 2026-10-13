# frozen_string_literal: true

# Maps neutral mail tags to ESP-specific SMTP headers.
module MailTagHeaders
  module_function

  def apply!(message, tags, provider:)
    tags = Array(tags).compact.map(&:to_s).reject(&:empty?)
    return if tags.empty? || provider.nil? || provider.to_s.empty?

    case provider.to_sym
    when :brevo
      tags.each { |tag| message['X-Mailin-Tag'] = tag }
    when :mailgun
      tags.each { |tag| message['X-Mailgun-Tag'] = tag }
    when :postmark
      # Postmark accepts a single tag only.
      message['X-PM-Tag'] = tags.join('|')
    when :sendgrid
      message['X-SMTPAPI'] = { category: tags }.to_json
    when :ses
      # SES expects key=value pairs; our tags are already "key:value".
      message['X-SES-MESSAGE-TAGS'] = tags.map { |tag| tag.sub(':', '=') }.join(', ')
    else
      raise ArgumentError, "Unknown action_mailer.smtp_provider: #{provider.inspect}"
    end
  end
end
