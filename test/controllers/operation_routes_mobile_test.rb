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
    @operation = publish_operation!(planning: @planning)
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

  test 'mobile preloads proof attachments and avoids planning graph queries' do
    visit_stops = @operation_route.operation_stops.executable.where(kind: 'visit').order(:index).to_a
    assert_operator visit_stops.size, :>=, 2
    visit_stops.first(2).each_with_index do |stop, index|
      stop.photos.attach(
        io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
        filename: "mobile_scope_#{index}.jpg",
        content_type: 'image/jpeg'
      )
    end

    attachment_queries = 0
    custom_attribute_queries = 0
    planning_graph_queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if sql.start_with?('SCHEMA') || payload[:cached]

      attachment_queries += 1 if sql.include?('active_storage_attachments')
      custom_attribute_queries += 1 if sql.include?('FROM "custom_attributes"') || sql.include?('FROM custom_attributes')
      if sql.match?(/FROM ["`]?(vehicle_usages|vehicle_usage_sets|stores|tag_vehicles|tag_vehicle_usages|stops)["`]?/i)
        planning_graph_queries += 1
      end
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      get "/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile?driver_token=#{@vehicle.driver_token}"
    end

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'stop-photo-open'
    assert_operator attachment_queries, :<=, 4,
                    "expected at most 4 active_storage_attachments queries, got #{attachment_queries}"
    assert_operator custom_attribute_queries, :<=, 2,
                    "expected at most 2 custom_attributes queries, got #{custom_attribute_queries}"
    assert_equal 0, planning_graph_queries,
                 "expected no planning graph queries, got #{planning_graph_queries}"
  ensure
    visit_stops&.each { |stop| stop.photos.purge if stop.photos.attached? }
  end

  test 'depot status is stored on the operation route' do
    patch "/operations/#{@operation.id}/routes/#{@operation_route.id}/update_status?driver_token=#{@vehicle.driver_token}",
          { leg: 'departure', status: 'atstore', status_updated_at: Time.current.iso8601 },
          'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'atstore', @operation_route.reload.departure_status
  end

  test 'historized operation locks the driver form in the UI' do
    @operation.update!(status: 'historized', closed_at: Time.current)

    get "/operations/#{@operation.id}/routes/#{@operation_route.id}/mobile?driver_token=#{@vehicle.driver_token}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, I18n.t('errors.routes.historized')
    refute_includes last_response.body, 'id="accordion"'
  end

  test 'queued driver status still flushes within the historized grace window' do
    closed_at = Time.zone.parse('2026-10-16 12:00')
    @operation.update!(status: 'historized', closed_at: closed_at)
    stop = @operation_route.operation_stops.find_by!(visit_id: visits(:visit_one).id)

    patch "/operation_stops/#{stop.id}?driver_token=#{@vehicle.driver_token}",
          { operation_stop: { status: 'delivered', status_updated_at: (closed_at - 1.minute).iso8601 } },
          'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'delivered', stop.reload.status
  end

  test 'driver status after the historized grace window is rejected' do
    closed_at = Time.zone.parse('2026-10-16 12:00')
    @operation.update!(status: 'historized', closed_at: closed_at)
    stop = @operation_route.operation_stops.find_by!(visit_id: visits(:visit_one).id)

    patch "/operation_stops/#{stop.id}?driver_token=#{@vehicle.driver_token}",
          { operation_stop: { status: 'delivered', status_updated_at: (closed_at + 13.hours).iso8601 } },
          'HTTP_ACCEPT' => 'application/json'
    assert_equal 422, last_response.status
    assert_nil stop.reload.status
  end

  test 'mobile shows the operation date and the stop time on that date' do
    @planning.update!(date: Date.new(2026, 1, 1))
    @operation.allow_past_date = true
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

  test 'mobile position update stores geolocation accuracy' do
    patch "/operations/#{@operation.id}/routes/#{@operation_route.id}/update_position?driver_token=#{@vehicle.driver_token}",
          {
            latitude: 48.8566,
            longitude: 2.3522,
            accuracy: 12.5,
            altitude: 40.0,
            heading: 90.0,
            speed: 4.2,
            positioned_at: Time.current.iso8601
          }.to_json,
          'CONTENT_TYPE' => 'application/json',
          'HTTP_ACCEPT' => 'application/json'

    assert_equal 200, last_response.status, last_response.body
    position = @operation_route.vehicle_positions.order(:id).last
    assert_in_delta 12.5, position.accuracy
    assert_in_delta 40.0, position.altitude
    assert_in_delta 90.0, position.heading
    assert_in_delta 4.2, position.speed
    assert_equal 'mobile', position.source
  end

  test 'mobile position update resolves planning route_id in the URL segment' do
    refute_equal @route.id, @operation_route.id

    patch "/operations/#{@operation.id}/routes/#{@route.id}/update_position?driver_token=#{@vehicle.driver_token}",
          {
            latitude: 48.85,
            longitude: 2.35,
            positioned_at: Time.current.iso8601
          }.to_json,
          'CONTENT_TYPE' => 'application/json',
          'HTTP_ACCEPT' => 'application/json'

    assert_equal 200, last_response.status, last_response.body
    assert @operation_route.vehicle_positions.exists?
  end

  test 'mobile position update rejects an id outside the operation' do
    other = publish_operation!(
      planning: plannings(:planning_one),
      clear: false,
      date: @operation.date + 1.day,
      route_ids: [@route.id]
    )
    other_route = other.operation_routes.find_by!(route_id: @route.id)

    patch "/operations/#{@operation.id}/routes/#{other_route.id}/update_position?driver_token=#{@vehicle.driver_token}",
          {
            latitude: 48.85,
            longitude: 2.35,
            positioned_at: Time.current.iso8601
          }.to_json,
          'CONTENT_TYPE' => 'application/json',
          'HTTP_ACCEPT' => 'application/json'

    assert_equal 404, last_response.status
  ensure
    other&.destroy!
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
    @operation = publish_operation!(planning: @planning)
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
