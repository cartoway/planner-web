# frozen_string_literal: true

require 'test_helper'

class OperationRoutesMobileTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @route = routes(:route_one_one)
    @planning = @route.planning
    Operation.where(customer_id: @planning.customer_id).delete_all
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @operation_route = @operation.operation_routes.find_by!(route_id: @route.id)
    @vehicle = @route.vehicle_usage.vehicle
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'operation route access follows the operation date' do
    last_stop = @operation_route.operation_stops.executable.where(kind: 'visit').order(:index).last
    last_stop.update!(stop_snapshot: last_stop.stop_snapshot.merge('time' => 23.hours.to_i))
    @operation.update_columns(date: Date.current)
    assert_not @operation_route.expired?
    @operation.update_columns(date: Date.current - 2)
    assert @operation_route.reload.expired?
  end

  test 'mobile form fields are stored on the operation stop and route' do
    stop = @operation_route.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    stop.update_columns(status: 'delivered')
    patch "/operation_stops/#{stop.id}?driver_token=#{@vehicle.driver_token}",
          { operation_stop: { custom_attributes: { 'stop_custom_field' => 'note chauffeur' } } },
          'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'note chauffeur', stop.reload.custom_attributes['stop_custom_field']
    refute_equal 'note chauffeur', stop.stop.reload.custom_attributes['stop_custom_field']
    assert_equal 'delivered', stop.status

    patch "/operations/#{@operation.id}/routes/#{@operation_route.id}/update_status?driver_token=#{@vehicle.driver_token}",
          { route: { custom_attributes: { 'route_info_visible' => 'info tournée' } } },
          'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'info tournée', @operation_route.reload.custom_attributes['route_info_visible']
    assert_nil @operation_route.departure_status
  end

  test 'driver reported quantities replace the planned amount on a delivered stop' do
    stop = @operation_route.operation_stops.find_by!(visit_id: visits(:visit_two).id)
    stop.update_columns(status: 'delivered')
    line = stop.quantity_lines.find { |row| row[:kind] == 'deliveries' && row[:unit_id].to_s == '1' }
    assert line
    before = stop.operation_route.board[:units].find { |unit| unit[:id] == '1' }[:delivered]

    patch "/operation_stops/#{stop.id}?driver_token=#{@vehicle.driver_token}",
          { operation_stop: { actual_quantities: { deliveries: { '1' => '1' } } } },
          'HTTP_ACCEPT' => 'application/json'

    assert_equal 200, last_response.status
    assert_equal 1.0, stop.reload.actual_quantity('deliveries', '1')
    after = stop.operation_route.board[:units].find { |unit| unit[:id] == '1' }[:delivered]
    assert_equal before - line[:value].to_f + 1, after
  end

  test 'mobile stop edit shows actual quantities with the mobile row layout' do
    stop = @operation_route.operation_stops.find_by!(visit_id: visits(:visit_two).id)
    assert stop.quantity_lines.any?

    get "/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile?driver_token=#{@vehicle.driver_token}"

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'actual_quantities'
    assert_includes last_response.body, 'actual_quantities-edit'
    assert_includes last_response.body, 'fa-pencil'
    assert_includes last_response.body, 'quantity-value'
    assert_includes last_response.body, 'input-group-addon'
    assert_includes last_response.body, 'quantity-planned'
    assert_includes last_response.body, 'operation_stop[actual_quantities]'
    assert_includes last_response.body, 'quantity-edit d-none'
    refute_includes last_response.body, I18n.t('operations.show.save_quantities')
  end

  test 'depot status is stored on the operation route' do
    patch "/operations/#{@operation.id}/routes/#{@operation_route.id}/update_status?driver_token=#{@vehicle.driver_token}",
          { leg: 'departure', status: 'atstore', status_updated_at: Time.current.iso8601 },
          'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'atstore', @operation_route.reload.departure_status
  end

  test 'mobile shows the operation date and the stop time on that date' do
    @planning.update!(date: Date.new(2026, 1, 1))
    @operation.update!(date: Date.new(2026, 9, 30))
    stop = @operation_route.operation_stops.where(kind: 'visit').order(:index).first
    stop.update!(stop_snapshot: stop.stop_snapshot.merge('time' => 8.hours.to_i))

    get "/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile?driver_token=#{@vehicle.driver_token}"

    assert_equal 200, last_response.status
    assert_includes last_response.body, '2026-09-30'
    refute_includes last_response.body, '2026-01-01'
    assert_includes last_response.body, '08:00'
  end

  test 'driver opens the operation route from snapshots' do
    get "/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile?driver_token=#{@vehicle.driver_token}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'vehicle_one'
    assert_includes last_response.body, 'route_one'
    assert_match(/id=['"]location-switch['"]/, last_response.body)
    assert_match(/for=['"]location-switch['"]/, last_response.body)
    assert_includes last_response.body, 'justify-content-end'
    refute_match(/form-switch[^>]*(text-right|text-end)/, last_response.body)
  end

  test 'driver status update keeps an older event without regressing the cursor' do
    stop = @operation_route.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    OperationStops::RecordStatus.call(operation_stop: stop, status: 'delivered', recorded_at: Time.zone.parse('2026-09-25 12:00'), source: 'mobile')
    patch "/operation_stops/#{stop.id}?driver_token=#{@vehicle.driver_token}",
          operation_stop: { status: 'started', status_updated_at: '2026-09-25T08:00:00Z' }
    assert_equal 302, last_response.status
    stop.reload
    assert_equal 'delivered', stop.status
    assert_equal 2, stop.operation_stop_status_events.count
  end

  test 'shortened mobile url targets the operation route' do
    shortener = mock
    shortener.expects(:shorten).with { |url|
      url.include?("/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile") &&
        url.include?("driver_token=#{@vehicle.driver_token}")
    }.returns('http://short.test/abc')
    Rails.application.config.stubs(:url_shortener).returns(shortener)

    assert_equal 'http://short.test/abc', Operations::MobileUrl.for(@operation_route)
  end

  test 'local mobile path does not shorten' do
    Rails.application.config.url_shortener.expects(:shorten).never

    path = Operations::MobileUrl.path(@operation_route)
    assert_includes path, "/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile"
    assert_includes path, "driver_token=#{@vehicle.driver_token}"
  end

  test 'planning send uses the operation mobile url' do
    shortener = mock
    shortener.expects(:shorten).with { |url|
      url.include?("/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile") &&
        url.include?("driver_token=#{@vehicle.driver_token}")
    }.returns('http://short.test/plan')
    Rails.application.config.stubs(:url_shortener).returns(shortener)

    assert_equal 'http://short.test/plan', Operations::MobileUrl.for_planning_route(@route)
  end

  test 'planning send has no mobile url without an open operation' do
    Operation.where(customer_id: @planning.customer_id).delete_all

    assert_nil Operations::MobileUrl.for_planning_route(@route)
  end
end

class OperationRouteMobileUrlTest < ActionController::TestCase
  tests OperationRoutesController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @planning = plannings(:planning_one)
    Operation.where(customer_id: @planning.customer_id).delete_all
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @operation_route = @operation.operation_routes.planned.first
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'returns a shortened driver mobile url' do
    shortener = mock
    shortener.expects(:shorten).returns('http://short.test/abc')
    Rails.application.config.stubs(:url_shortener).returns(shortener)

    get :mobile_url, params: { operation_id: @operation.id, id: @operation_route.id }
    assert_response :success
    assert_equal 'http://short.test/abc', JSON.parse(response.body)['url']
  end
end
