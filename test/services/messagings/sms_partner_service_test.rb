require 'test_helper'

class SmsPartnerServiceTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @reseller = @customer.reseller
    @service = SmsPartnerService.new(@customer)

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
    assert SmsPartnerService.configured?(@customer)
  end

  test 'should not be configured when disabled' do
    @reseller.messagings['sms_partner']['enable'] = false
    @reseller.save!

    refute SmsPartnerService.configured?(@customer)
  end

  test 'should send message' do
    Smspartner.expects(:configure).yields(mock.tap { |m|
      m.expects(:api_key=).with('test_key')
      m.expects(:sender=).with('SENDER')
      m.expects(:range_value=).with(:premium)
    })

    response = mock
    response.expects(:success?).returns(true)
    response.expects(:message_id).returns('msg_id')
    response.expects(:raw_data).returns({
      'total_cost' => '0.05',
      'total_sms' => 1
    }).twice

    Smspartner.expects(:send_sms).with(
      to: '+33612345678',
      body: 'Test message'
    ).returns(response)

    assert @service.send_message(
      '0612345678',
      'Test message',
      sender: 'SENDER',
      country: 'France'
    )
  end
end
