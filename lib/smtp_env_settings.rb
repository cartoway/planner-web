# frozen_string_literal: true

# Classic SMTP settings from ENV (with safe local defaults).
module SmtpEnvSettings
  module_function

  def to_h
    {
      address: ENV.fetch('SMTP_ADDRESS', 'smtp.example.com').to_s.strip,
      port: Integer(ENV.fetch('SMTP_PORT', '587')),
      user_name: ENV.fetch('SMTP_USER_NAME', 'robot@example.com').to_s.strip,
      password: ENV.fetch('SMTP_PASSWORD', ''),
      authentication: ENV.fetch('SMTP_AUTHENTICATION', 'plain'),
      enable_starttls: ENV.fetch('SMTP_ENABLE_STARTTLS', 'true') != 'false',
      open_timeout: Integer(ENV.fetch('SMTP_OPEN_TIMEOUT', '5')),
      read_timeout: Integer(ENV.fetch('SMTP_READ_TIMEOUT', '5'))
    }
  end

  def provider
    ENV['SMTP_PROVIDER'].presence&.to_sym
  end

  def default_from
    ENV.fetch('SMTP_DEFAULT_FROM', 'root@localhost')
  end

  # :smtp (default) | :letter_opener_web | :letter_opener | :test
  # letter_opener → letter_opener_web in containers (no local browser to open).
  def delivery_method
    raw = ENV['SMTP_DELIVERY_METHOD'].presence || 'smtp'
    raw = 'letter_opener_web' if raw == 'letter_opener'
    raw.to_sym
  end
end
