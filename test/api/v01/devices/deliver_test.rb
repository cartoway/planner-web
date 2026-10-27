require 'test_helper'

class V01::Devices::DeliverTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join('test/lib/devices/api_base')
  include ApiBase

  require Rails.root.join('test/lib/devices/deliver_base')
  include DeliverBase

  setup do
    @customer = customers(:customer_one)
    @customer.update!(
      devices: { deliver: { enable: true } },
      enable_vehicle_position: true,
      enable_proofs: true,
      enable_email_driver: true,
      enable_sms_driver: false
    )
    set_route
    Operation.where(customer_id: @customer.id).delete_all
    @planning = plannings(:planning_one)
    @planning_route = routes(:route_one_one)
    @operation = publish_operation!(planning: @planning, route_ids: [@planning_route.id])
    @operation_route = @operation.operation_routes.find_by!(route_id: @planning_route.id)
    @operation_route.update!(vehicle_snapshot: (@operation_route.vehicle_snapshot || {}).merge('contact_email' => 'driver@example.com'))
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'send and send_multiple transmit operation routes' do
    post api('devices/deliver/send', { customer_id: @customer.id, operation_route_id: @operation_route.id, channel: 'email' })
    assert_equal 201, last_response.status, last_response.body
    rows = JSON.parse(last_response.body)
    assert_equal @operation_route.id, rows.first['id']
    assert_equal 'email', @operation_route.reload.last_sent_to
    assert @operation_route.last_sent_at

    @operation_route.update_columns(last_sent_at: nil, last_sent_to: nil)

    post api('devices/deliver/send_multiple', { customer_id: @customer.id, operation_id: @operation.id, channel: 'email' })
    assert_equal 201, last_response.status, last_response.body
    rows = JSON.parse(last_response.body)
    assert rows.any? { |row| row['id'] == @operation_route.id && row['last_sent_to'] == 'email' }
    assert_equal 'email', @operation_route.reload.last_sent_to
  end

  test 'clear and clear_multiple endpoints are gone' do
    delete api('devices/deliver/clear', { customer_id: @customer.id, operation_route_id: @operation_route.id })
    assert_equal 404, last_response.status

    delete api('devices/deliver/clear_multiple', customer_id: @customer.id), operation_id: @operation.id
    assert_equal 404, last_response.status
  end
end
