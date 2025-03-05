require 'test_helper'

class MessagingServiceTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @reseller = @customer.reseller
  end

  test 'should format content with replacements' do
    service = MessagingService.new(@reseller, customer: @customer)
    template = "Hello {NAME}, your delivery is scheduled for {DATE} at {TIME}"
    time = Time.zone.parse('2024-02-25 14:30')

    content = service.content(
      template,
      replacements: {
        name: 'John',
        date: time.to_date,
        time: time
      }
    )

    assert_equal 'Hello John, your delivery is scheduled for 25/02/2024 at 14:30', content
  end

  test 'should truncate content by default' do
    service = MessagingService.new(@reseller, customer: @customer)
    long_text = 'x' * 200

    content = service.content(long_text)
    assert_equal 160, content.length
  end

  test 'should not truncate content when specified' do
    service = MessagingService.new(@reseller, customer: @customer)
    long_text = 'x' * 200

    content = service.content(long_text, truncate: false)
    assert_equal 200, content.length
  end

  test 'should format phone numbers' do
    service = MessagingService.new(@reseller, customer: @customer)

    assert_raises(CountryCodeError) { service.send(:format_phone_number, '0612345678') }
    assert_equal '+33612345678', service.send(:format_phone_number, '0612345678', 'France')
    assert_equal '+33612345678', service.send(:format_phone_number, '+33612345678')
    assert_equal [], service.send(:format_phone_number, '0112345678', 'France')
    assert_equal '+447105850070', service.send(:format_phone_number, '07105850070', 'United Kingdom')
  end

  test 'should raise NotImplementedError for balance in base class' do
    service = MessagingService.new(@customer.reseller, customer: @customer)
    assert_raises(NotImplementedError) { service.balance }
  end

  test 'should return nil for vonage balance when api_key is missing' do
    @reseller.update!(
      messagings: {
        sms_partner: { enable: false },
        vonage: { enable: true, api_secret: 'secret' }
      }
    )
    service = VonageService.new(@customer.reseller, customer: @customer)
    assert_nil service.balance
  end

  test 'should return nil for vonage balance when api_secret is missing' do
    @reseller.update!(
      messagings: {
        vonage: { enable: true, api_key: 'key' }
      }
    )
    service = VonageService.new(@customer.reseller, customer: @customer)
    assert_nil service.balance
  end

  test 'should return nil for vonage balance when both credentials are missing' do
    @reseller.update!(
      messagings: {
        vonage: { enable: true }
      }
    )
    service = VonageService.new(@customer.reseller, customer: @customer)
    assert_nil service.balance
  end

  test 'should return nil for sms_partner balance when api_key is missing' do
    @reseller.update!(
      messagings: {
        sms_partner: { enable: true }
      }
    )
    service = SmsPartnerService.new(@customer.reseller, customer: @customer)
    assert_nil service.balance
  end

  test 'should return nil for sms_partner balance when api_key is empty' do
    @reseller.update!(
      messagings: {
        sms_partner: { enable: true, api_key: '' }
      }
    )
    service = SmsPartnerService.new(@customer.reseller, customer: @customer)
    assert_nil service.balance
  end

  test 'should return nil for sms_partner balance when api_key is blank' do
    @reseller.update!(
      messagings: {
        sms_partner: { enable: true, api_key: '   ' }
      }
    )
    service = SmsPartnerService.new(@customer.reseller, customer: @customer)
    assert_nil service.balance
  end

  test 'should return balance for vonage when credentials are present' do
    @reseller.update!(
      messagings: {
        vonage: { enable: true, api_key: 'key', api_secret: 'secret' },
        sms_partner: { enable: false }
      }
    )
    service = VonageService.new(@customer.reseller, customer: @customer)

    Vonage::Client.any_instance.stubs(:account).returns(
      OpenStruct.new(balance: OpenStruct.new(value: 100.0))
    )

    assert_equal 100.0, service.balance
  end

  test 'should return balance for sms_partner when api_key is present' do
    @reseller.update!(
      messagings: {
        sms_partner: { enable: true, api_key: 'key' }
      }
    )
    service = SmsPartnerService.new(@customer.reseller, customer: @customer)

    RestClient.stubs(:get).returns(
      OpenStruct.new(
        body: {
          success: true,
          credits: { balance: 100.0 }
        }.to_json
      )
    )

    assert_equal 100.0, service.balance
  end

  test 'should return nil for sms_partner when response is not successful' do
    @reseller.update!(
      messagings: {
        sms_partner: { enable: true, api_key: 'key' }
      }
    )
    service = SmsPartnerService.new(@customer.reseller, customer: @customer)
    RestClient.stubs(:get).returns(OpenStruct.new(body: { success: false }.to_json))
    SmsPartnerService::SmsPartnerResponse.any_instance.stubs(:success?).returns(false)
    SmsPartnerService::SmsPartnerResponse.any_instance.stubs(:errors).returns(['Invalid API key'])

    assert_nil service.balance
  end
end
