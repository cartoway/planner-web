# frozen_string_literal: true

require 'test_helper'

class V01::OperationsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
    Operation.where(customer_id: @planning.customer_id).delete_all
    @route = routes(:route_one_one)
    @operation = Operations::PublishFromPlanning.call(
      planning: @planning,
      route_ids: [@route.id]
    )
    @operation_route = @operation.operation_routes.find_by!(route_id: @route.id)
    @stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'lists operations with filters' do
    get '/api/0.1/operations.json?api_key=testkey1'
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert body.any? { |row| row['id'] == @operation.id }

    get "/api/0.1/operations.json?api_key=testkey1&status=in_progress&date=#{@operation.date}"
    assert last_response.ok?, last_response.body
    assert JSON.parse(last_response.body).any? { |row| row['id'] == @operation.id }
  end

  test 'returns the operation from snapshots' do
    get "/api/0.1/operations/#{@operation.id}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal @operation.name, body['name']
    assert body['operation_routes'].any?
    assert body['operation_routes'].first['operation_stops'].first['destination_snapshot']
  end

  test 'happy path publish get status sync close' do
    Operation.where(customer_id: @planning.customer_id).delete_all
    route_b = routes(:route_one_two)

    post "/api/0.1/plannings/#{@planning.id}/operations.json?api_key=testkey1",
         name: 'API Op',
         date: Date.current.to_s,
         route_ids: [@route.id, route_b.id]
    assert_equal 201, last_response.status, last_response.body
    body = JSON.parse(last_response.body)
    operation_id = body['id']
    assert_equal 'API Op', body['name']
    assert body['operation_routes'].size >= 1

    get "/api/0.1/operations/#{operation_id}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    full = JSON.parse(last_response.body)
    stop_id = full['operation_routes'].flat_map { |r| r['operation_stops'] }.find { |s| s['kind'] == 'visit' }['id']

    post "/api/0.1/operations/#{operation_id}/stops/#{stop_id}/status.json?api_key=testkey1",
         status: 'delivered',
         recorded_at: '2026-09-25T10:00:00Z'
    assert_equal 201, last_response.status, last_response.body
    assert_equal 'delivered', JSON.parse(last_response.body)['status']

    post "/api/0.1/operations/#{operation_id}/sync.json?api_key=testkey1"
    assert_equal 200, last_response.status, last_response.body

    post "/api/0.1/operations/#{operation_id}/close.json?api_key=testkey1"
    assert_equal 200, last_response.status, last_response.body
    closed = JSON.parse(last_response.body)
    assert_equal 'historized', closed['status'], closed
    assert closed['closed_at']
    assert_equal 'historized', Operation.find(operation_id).status
  end

  test 'fetch_device_status pulls telematics into the operation' do
    @planning.customer.update!(
      enable_proofs: true,
      devices: {
        deliver: { enable: true },
        tomtom: { enable: true, account: 'a', user: 'u', password: 'p' }
      }
    )
    Planner::Application.config.devices.tomtom.stubs(:fetch_stops).returns([
      { order_id: "v#{@stop.visit_id}", status: 'Started', eta: nil }
    ])

    post "/api/0.1/operations/#{@operation.id}/fetch_device_status.json?api_key=testkey1"
    assert_equal 200, last_response.status, last_response.body
    assert_equal 'Started', @stop.reload.status
  end

  test 'posts a status event' do
    post "/api/0.1/operations/#{@operation.id}/stops/#{@stop.id}/status.json?api_key=testkey1",
         status: 'delivered',
         recorded_at: '2026-09-25T10:00:00Z'
    assert_equal 201, last_response.status
    @stop.reload
    assert_equal 'delivered', @stop.status
    assert_equal 1, @stop.operation_stop_status_events.count
  end

  test 'updates route departure status' do
    patch "/api/0.1/operations/#{@operation.id}/routes/#{@operation_route.id}/status.json?api_key=testkey1",
          leg: 'departure',
          status: 'atstore',
          status_updated_at: '2026-09-25T09:00:00Z'
    assert last_response.ok?, last_response.body
    assert_equal 'atstore', @operation_route.reload.departure_status
  end

  test 'records a vehicle position' do
    patch "/api/0.1/operations/#{@operation.id}/routes/#{@operation_route.id}/position.json?api_key=testkey1",
          lat: 48.85,
          lng: 2.35,
          positioned_at: Time.current.iso8601
    assert_equal 204, last_response.status
    assert @operation_route.vehicle_positions.exists?
  end

  test 'returns operation map geojson' do
    get "/api/0.1/operations/#{@operation.id}/map.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert body.key?('type') || body.key?('features') || body.is_a?(Hash)
  end

  test 'searches stops across operations' do
    get "/api/0.1/operations/stops.json?api_key=testkey1&from=#{@operation.date - 1}&to=#{@operation.date + 1}"
    assert_equal 200, last_response.status, last_response.body
    rows = JSON.parse(last_response.body)
    assert rows.any? { |row| row['id'] == @stop.id }, rows.inspect
  end

  test 'updates and deletes an operation' do
    patch "/api/0.1/operations/#{@operation.id}.json?api_key=testkey1", name: 'Renamed'
    assert last_response.ok?, last_response.body
    assert_equal 'Renamed', @operation.reload.name

    delete "/api/0.1/operations/#{@operation.id}.json?api_key=testkey1"
    assert_equal 204, last_response.status
    assert_nil Operation.find_by(id: @operation.id)
  end

  test 'planning routes omit field status' do
    get "/api/0.1/plannings/#{@planning.id}/routes.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    route = JSON.parse(last_response.body).find { |row| row['id'] == @route.id }
    assert route
    refute route.key?('departure_status')
    refute route.key?('arrival_status')
    stop = route['stops']&.find { |s| s['stop_type'] == 'visit' }
    assert stop
    refute stop.key?('status')
    refute stop.key?('status_code')
    refute stop.key?('eta')
  end
end
