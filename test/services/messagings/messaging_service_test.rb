require 'test_helper'

class MessagingServiceTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @reseller = @customer.reseller
  end

  test 'should format content with replacements' do
    service = MessagingService.new(@customer)
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
    service = MessagingService.new(@customer)
    long_text = 'x' * 200

    content = service.content(long_text)
    assert_equal 160, content.length
  end

  test 'should not truncate content when specified' do
    service = MessagingService.new(@customer)
    long_text = 'x' * 200

    content = service.content(long_text, truncate: false)
    assert_equal 200, content.length
  end

  test 'should format phone numbers' do
    service = MessagingService.new(@customer)

    assert_raises(CountryCodeError) { service.send(:format_phone_number, '0612345678') }
    assert_equal '+33612345678', service.send(:format_phone_number, '0612345678', 'France')
    assert_equal '+33612345678', service.send(:format_phone_number, '+33612345678')
    assert_equal [], service.send(:format_phone_number, '0112345678', 'France')
    assert_equal '+447105850070', service.send(:format_phone_number, '07105850070', 'United Kingdom')
  end
end
