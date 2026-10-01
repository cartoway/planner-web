# frozen_string_literal: true

require 'test_helper'

class SendDestinationNotificationsTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @operation = Operations::PublishFromPlanning.call(planning: @planning, date: Date.current)
    @tracking = @operation.operation_delivery_trackings.first
    stop = @tracking.visit_stops.first
    stop.update!(destination_snapshot: stop.destination_snapshot.merge(
      'phone_number' => '0601020304',
      'email' => 'dest@example.com',
      'name' => 'Alice'
    ))
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'send destination email injects tracking url' do
    @customer.update!(recipient_template: 'Bonjour {NAME} {URL}')
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      count = Operations::SendDestinationEmail.call(operation: @operation, trackings: [@tracking])
      assert_equal 1, count
    end
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.to, 'dest@example.com'
    assert_match %r{/s/#{Regexp.escape(@tracking.token)}|http}, mail.body.encoded
  end

  test 'send destination sms builds content with shortened url' do
    messaging = Object.new
    def messaging.content(template, replacements:, truncate: true)
      "#{replacements[:name]} #{replacements[:url]}"
    end

    # rubocop:disable Naming/PredicateMethod
    def messaging.send_message(*)
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def messaging.class
      Class.new {
        def self.name
          'FakeSms'
        end
      }.new.class
    end

    Operations::SendDriverSms.stubs(:messaging_service).returns(messaging)
    @customer.update!(sms_template: 'Hi {NAME} {URL}')
    count = Operations::SendDestinationSms.call(operation: @operation, trackings: [@tracking])
    assert_equal 1, count
  end
end
