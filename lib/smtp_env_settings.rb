# frozen_string_literal: true

# Classic SMTP settings from ENV (with safe local defaults).
module SmtpEnvSettings
  module_function

  def to_h
    {
      # Compose often injects SMTP_*=${SMTP_*:-} as "" when unset; treat blank as missing.
      address: (ENV['SMTP_ADDRESS'].presence || 'smtp.example.com').to_s.strip,
      port: Integer(ENV['SMTP_PORT'].presence || '587'),
      user_name: (ENV['SMTP_USER_NAME'].presence || 'robot@example.com').to_s.strip,
      password: ENV['SMTP_PASSWORD'].to_s,
      authentication: ENV['SMTP_AUTHENTICATION'].presence || 'plain',
      enable_starttls: (ENV['SMTP_ENABLE_STARTTLS'].presence || 'true') != 'false',
      open_timeout: Integer(ENV['SMTP_OPEN_TIMEOUT'].presence || '5'),
      read_timeout: Integer(ENV['SMTP_READ_TIMEOUT'].presence || '5')
    }
  end

  def provider
    ENV['SMTP_PROVIDER'].presence&.to_sym
  end

  def default_from
    ENV['SMTP_DEFAULT_FROM'].presence || 'root@localhost'
  end

  # :smtp (default) | :letter_opener_web | :letter_opener | :test
  # letter_opener → letter_opener_web in containers (no local browser to open).
  def delivery_method
    raw = ENV['SMTP_DELIVERY_METHOD'].presence || 'smtp'
    raw = 'letter_opener_web' if raw == 'letter_opener'
    raw.to_sym
  end
end
