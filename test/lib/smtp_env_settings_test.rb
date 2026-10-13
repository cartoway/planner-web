# frozen_string_literal: true

require 'test_helper'

class SmtpEnvSettingsTest < ActiveSupport::TestCase
  test 'to_h reads SMTP settings from ENV with defaults' do
    with_env(
      'SMTP_ADDRESS' => 'smtp.brevo.com',
      'SMTP_PORT' => '2525',
      'SMTP_USER_NAME' => 'user@example.com',
      'SMTP_PASSWORD' => 'secret',
      'SMTP_AUTHENTICATION' => 'login',
      'SMTP_ENABLE_STARTTLS' => 'false'
    ) do
      settings = SmtpEnvSettings.to_h
      assert_equal 'smtp.brevo.com', settings[:address]
      assert_equal 2525, settings[:port]
      assert_equal 'user@example.com', settings[:user_name]
      assert_equal 'secret', settings[:password]
      assert_equal 'login', settings[:authentication]
      assert_equal false, settings[:enable_starttls]
    end
  end

  test 'provider reads SMTP_PROVIDER' do
    with_env('SMTP_PROVIDER' => 'brevo') do
      assert_equal :brevo, SmtpEnvSettings.provider
    end
  end

  private

  def with_env(vars)
    previous = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
