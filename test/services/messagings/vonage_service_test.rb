require 'test_helper'

class VonageServiceTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @reseller = @customer.reseller
    @service = VonageService.new(@customer)

    @reseller.update!(
      messagings: {
        'vonage' => {
          'enable' => true,
          'api_key' => 'test_key',
          'api_secret' => 'test_secret'
        }
      }
    )
  end

  test 'should be configured when enabled' do
    assert VonageService.configured?(@customer)
  end

  test 'should not be configured when disabled' do
    @reseller.messagings['vonage']['enable'] = false
    @reseller.save!

    refute VonageService.configured?(@customer)
  end

  test 'should send message' do
    vonage_client = mock
    vonage_sms = mock
    response = mock
    message = mock

    Vonage::Client.expects(:new).with(
      api_key: 'test_key',
      api_secret: 'test_secret'
    ).returns(vonage_client)

    vonage_client.expects(:sms).returns(vonage_sms)
    vonage_sms.expects(:send).with(
      from: 'SENDER',
      to: '+33612345678',
      text: 'Test message',
      message_id: '123'
    ).returns(response)

    response.expects(:messages).returns([message]).twice
    message.expects(:status).returns('0')

    assert @service.send_message(
      '0612345678',
      'Test message',
      from: 'SENDER',
      message_id: '123',
      country: 'France'
    )
  end
end
