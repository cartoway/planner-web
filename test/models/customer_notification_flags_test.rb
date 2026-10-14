# frozen_string_literal: true

require 'test_helper'

class CustomerNotificationFlagsTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'default_sms_sender_name prefers company_name over account name and truncates' do
    @customer.company_name = 'Acme Societe Longue'
    @customer.name = 'Compte Acme'
    assert_equal 'Acme Societ', @customer.default_sms_sender_name
    assert_equal 'Acme Societ', @customer.effective_sms_sender_name

    @customer.company_name = '  '
    assert_equal 'Compte Acme', @customer.default_sms_sender_name
  end

  test 'effective_sms_sender_name uses custom sms_sender_name when set' do
    @customer.company_name = 'Acme SA'
    @customer.sms_sender_name = 'MonSMS'
    assert_equal 'MonSMS', @customer.effective_sms_sender_name
  end

  test 'sms_sender_name must be between 3 and 11 characters' do
    @customer.sms_sender_name = 'AB'
    assert_not @customer.valid?
    assert @customer.errors[:sms_sender_name].any?

    @customer.sms_sender_name = 'ABCDEFGHIJKL'
    assert_not @customer.valid?

    @customer.sms_sender_name = 'ValidName'
    assert @customer.valid?
  end
end
