require 'test_helper'

class V01::Devices::DeliverTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join('test/lib/devices/api_base')
  include ApiBase

  require Rails.root.join('test/lib/devices/deliver_base')
  include DeliverBase

  setup do
    @customer = customers(:customer_one)
    @customer.update(devices: { deliver: { enable: true } }, enable_vehicle_position: true, enable_stop_status: true)
    set_route
  end

  def planning_api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings#{part}.json?api_key=testkey1&" + param.collect { |k, v| "#{k}=" + URI.escape(v.to_s) }.join('&')
  end

  test 'should send route' do
    route = routes(:route_one_one)
    post api('devices/deliver/send', { customer_id: @customer.id, route_id: route.id })
    assert_equal 201, last_response.status, last_response.body
    route.reload
    assert route.reload.last_sent_at
    assert_equal({ 'id' => route.id, 'last_sent_to' => 'Deliver', 'last_sent_at' => route.last_sent_at.iso8601(3), 'last_sent_at_formatted' => I18n.l(route.last_sent_at) }, JSON.parse(last_response.body))
  end

  test 'should send multiple routes' do
    planning = plannings(:planning_one)
    post api('devices/deliver/send_multiple', { customer_id: @customer.id, planning_id: planning.id })
    assert_equal 201, last_response.status, last_response.body
    routes = planning.routes.select(&:vehicle_usage_id)
    routes.each(&:reload)
    assert_equal(
      routes.map{ |route| {
        'id' => route.id, 'last_sent_to' => 'Deliver', 'last_sent_at' => route.last_sent_at.iso8601(3), 'last_sent_at_formatted' => I18n.l(route.last_sent_at)
      }},
      JSON.parse(last_response.body))
  end

  test 'should clear' do
    route = routes(:route_one_one)
    delete api('devices/deliver/clear', { customer_id: @customer.id, route_id: route.id })
    assert_equal 200, last_response.status
    route.reload
    assert !route.last_sent_at
    assert_equal({ 'id' => route.id, 'last_sent_to' => nil, 'last_sent_at' => nil, 'last_sent_at_formatted' => nil }, JSON.parse(last_response.body))
  end

  test 'should clear multiple' do
    planning = plannings(:planning_one)
    route = routes(:route_one_one)
    route_three = routes(:route_three_one)
    service = FleetService.new(customer: @customer).service
    ref = service.send(:generate_route_id, route, service.p_time(route, route.start))
    route.update(last_sent_at: Time.now, last_sent_to: 'Mapo.Live')

    delete api('devices/deliver/clear_multiple', customer_id: @customer.id), planning_id: planning.id
    assert_equal 200, last_response.status

    assert_equal([route_three.id, nil, nil, nil, route.id, nil, nil, nil],
      JSON.parse(last_response.body).flat_map{ |rt|
        [rt['id'], rt['last_sent_to'], rt['last_sent_at'], rt['last_sent_at_formatted']]
      })

    routes = planning.routes.select(&:vehicle_usage_id)
    routes.each(&:reload)
    routes.each { |rt| assert !rt.last_sent_at }
  end
end
