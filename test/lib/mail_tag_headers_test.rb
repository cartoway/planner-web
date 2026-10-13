# frozen_string_literal: true

require 'test_helper'

class MailTagHeadersTest < ActiveSupport::TestCase
  setup do
    @tags = %w[mail_type:password_message reseller_id:1 customer_id:2]
  end

  test 'brevo adds X-Mailin-Tag for each tag' do
    message = Mail::Message.new
    MailTagHeaders.apply!(message, @tags, provider: :brevo)
    values = message.header.fields.select { |f| f.name == 'X-Mailin-Tag' }.map(&:value)
    assert_equal @tags, values
  end

  test 'mailgun adds X-Mailgun-Tag for each tag' do
    message = Mail::Message.new
    MailTagHeaders.apply!(message, @tags, provider: :mailgun)
    values = message.header.fields.select { |f| f.name == 'X-Mailgun-Tag' }.map(&:value)
    assert_equal @tags, values
  end

  test 'postmark joins tags into a single X-PM-Tag' do
    message = Mail::Message.new
    MailTagHeaders.apply!(message, @tags, provider: :postmark)
    assert_equal @tags.join('|'), message['X-PM-Tag'].to_s
  end

  test 'sendgrid sets X-SMTPAPI categories' do
    message = Mail::Message.new
    MailTagHeaders.apply!(message, @tags, provider: :sendgrid)
    payload = JSON.parse(message['X-SMTPAPI'].to_s)
    assert_equal @tags, payload['category']
  end

  test 'ses maps tags to X-SES-MESSAGE-TAGS key=value list' do
    message = Mail::Message.new
    MailTagHeaders.apply!(message, @tags, provider: :ses)
    assert_equal 'mail_type=password_message, reseller_id=1, customer_id=2', message['X-SES-MESSAGE-TAGS'].to_s
  end

  test 'blank provider is a no-op' do
    message = Mail::Message.new
    MailTagHeaders.apply!(message, @tags, provider: nil)
    assert_empty message.header.fields.select { |f| f.name.match?(/Tag|SMTPAPI|SES/i) }
  end
end
