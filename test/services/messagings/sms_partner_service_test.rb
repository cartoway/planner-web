require 'test_helper'

class SmsPartnerServiceTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @reseller = @customer.reseller
    @service = SmsPartnerService.new(@reseller, customer: @customer)

    @reseller.update!(
      messagings: {
        'sms_partner' => {
          'enable' => true,
          'api_key' => 'test_key'
        }
      }
    )
  end

  test 'should be configured when enabled' do
    assert SmsPartnerService.configured?(@reseller)
  end

  test 'should not be configured when disabled' do
    @reseller.messagings['sms_partner']['enable'] = false
    @reseller.save!

    refute SmsPartnerService.configured?(@reseller)
  end

  test 'should send message' do
    response = mock
    response.expects(:body).returns({
      'success' => true,
      'message_id' => 'msg_id',
      'code' => 200
    }.to_json)

    RestClient.expects(:post).with(
      SmsPartnerService::SEND_SMS_URL,
      {
        phoneNumbers: '+33612345678',
        message: 'Test message',
        apiKey: 'test_key',
        sender: 'SENDER',
        gamme: 1,
        isStopSms: false,
        tag: "c#{@customer.id}"
      }.to_json,
      { content_type: :json, accept: :json }
    ).returns(response)

    assert @service.send_message(
      '0612345678',
      'Test message',
      from: 'SENDER',
      country: 'France'
    )
  end

  test 'should return false and log when send fails with errors array' do
    response = mock
    response.expects(:body).returns({
      'success' => false,
      'code' => 9,
      'errors' => [
        { 'elementId' => 'children[phoneNumbers].data', 'message' => 'This phone number is not valid' }
      ]
    }.to_json)

    RestClient.expects(:post).returns(response)

    Rails.logger.expects(:error).with('SmsPartnerService error: SMS sending failed')
    Rails.logger.expects(:error).with('  errors: This phone number is not valid')

    refute @service.send_message('0612345678', 'Test message', from: 'SENDER', country: 'France')
  end
end
