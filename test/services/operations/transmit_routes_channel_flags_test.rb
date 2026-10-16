# frozen_string_literal: true

require 'test_helper'

class TransmitRoutesChannelFlagsTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @operation = Operations::PublishFromPlanning.call(planning: @planning, date: Date.current)
    @route = @operation.operation_routes.planned.where.not(vehicle_id: nil).first
    @route.update!(vehicle_snapshot: @route.vehicle_snapshot.merge(
      'contact_email' => 'driver@example.com',
      'phone_number' => '0601020304'
    ))
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'driver email is skipped when enable_email_driver is false' do
    @customer.update!(enable_email_driver: false, enable_sms_driver: false)
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      result = Operations::TransmitRoutes.call(operation: @operation, routes: [@route])
      assert_equal 0, result[:emailed]
      assert_equal 0, result[:sms]
    end
  end

  test 'driver sms is skipped when enable_sms_driver is false' do
    @customer.update!(enable_email_driver: false, enable_sms_driver: false)
    assert_equal 0, Operations::SendDriverSms.call(operation: @operation, routes: [@route])
  end

  test 'driver email and sms are skipped once the operation is historized' do
    @customer.update!(enable_email_driver: true, enable_sms_driver: true)
    @operation.update!(status: 'historized', closed_at: Time.current)

    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      result = Operations::TransmitRoutes.call(operation: @operation, routes: [@route])
      assert_equal 0, result[:emailed]
      assert_equal 0, result[:sms]
    end
    assert_equal 0, Operations::SendDriverSms.call(operation: @operation, routes: [@route])
    assert_equal false, Operations::TransmitRoutes.send_email(@route)
  end
end
