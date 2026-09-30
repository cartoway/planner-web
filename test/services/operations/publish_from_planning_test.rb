# frozen_string_literal: true

require 'test_helper'

class PublishFromPlanningTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'expected stop time follows the operation date' do
    @planning.update!(date: Date.new(2026, 1, 1))
    operation = Operations::PublishFromPlanning.call(planning: @planning, date: '2026-09-30')
    stop = operation.operation_stops.where(kind: 'visit').order(:index).first
    stop.update!(stop_snapshot: stop.stop_snapshot.merge('time' => 26.hours.to_i))

    assert_equal Time.zone.local(2026, 10, 1, 2, 0, 0), stop.planned_at
    assert_equal "#{I18n.l(Date.new(2026, 10, 1))} 02:00", stop.passage_time

    stop.update!(stop_snapshot: stop.stop_snapshot.merge('time' => 8.hours.to_i))
    assert_equal '08:00', stop.reload.passage_time
  end

  test 'operation board sums every route' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    routes = operation.operation_routes.active_sync.to_a
    assert_operator routes.size, :>, 1
    routes.each { |route| route.operation_stops.where(kind: 'visit').update_all(status: 'delivered') }

    board = operation.board
    routes.each(&:reload)
    assert_equal routes.sum { |route| route.board[:delivered] }, board[:delivered]
    assert_equal routes.sum { |route| route.board[:total] }, board[:total]
    assert_equal routes.sum { |route| route.board[:distance] }, board[:distance]
    assert_operator board[:delivered], :>, routes.first.board[:delivered]
    assert_equal 0, board[:sent]
    assert_equal routes.count { |route| !route.unassigned }, board[:routes]

    routes.first.update_columns(last_sent_at: Time.current, last_sent_to: 'email')
    assert_equal 1, operation.board[:sent]
  end

  test 'publish dates the operation from the customer offset' do
    @customer.update!(operation_date_offset: 4)

    operation = Operations::PublishFromPlanning.call(planning: @planning)

    assert_equal Date.current + 4, operation.date
  end

  test 'publish can keep only visible routes and the chosen date' do
    routes(:route_three_one).update_columns(hidden: true)

    operation = Operations::PublishFromPlanning.call(
      planning: @planning,
      date: '2026-09-25',
      visible_routes_only: true
    )

    assert_equal Date.new(2026, 9, 25), operation.date
    assert operation.operation_routes.exists?(route_id: routes(:route_one_one).id)
    assert_nil operation.operation_routes.find_by(route_id: routes(:route_three_one).id)
    assert operation.current_structure?(@planning)
  end

  test 'publish skips inactive stops and the unplanned route' do
    inactive = stops(:stop_one_two)
    inactive.update_columns(active: false)

    operation = Operations::PublishFromPlanning.call(planning: @planning)

    assert_nil operation.operation_routes.find_by(route_id: routes(:route_zero_one).id)
    assert operation.operation_routes.where(unassigned: true).none?
    assert_nil operation.operation_stops.find_by(stop_id: inactive.id)
    assert operation.operation_stops.where(stop_id: stops(:stop_one_one).id).exists?
  end

  test 'sync drops a stop that became inactive or unplanned' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    stop = operation.operation_stops.find_by!(stop_id: stops(:stop_one_one).id)
    stops(:stop_one_one).update_columns(active: false)

    Operations::SyncFromPlanning.call(planning: @planning.reload, operation: operation.reload)

    assert_equal 'orphaned', stop.reload.sync_state
  end

  test 'board splits delivered quantities from quantities still to load' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    stop = operation.operation_stops.joins(:visit).find_by!(visit_id: visits(:visit_two).id)
    stop.update!(status: 'delivered')
    unit = operation.operation_routes.find(stop.operation_route_id).board[:units].find { |row| row[:id] == '1' }

    assert unit
    assert_equal 3.0, unit[:delivered]
    assert_operator unit[:collected], :<=, unit[:pickup]
  end

  test 'route quantities use non-null deliverable unit defaults' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    operation.update!(deliverable_units_snapshot: [{
      'id' => 9, 'label' => 'Kg', 'icon' => 'fa-weight-hanging',
      'default_delivery' => 2, 'default_pickup' => 1
    }])
    route = operation.operation_routes.planned.first
    visits = route.operation_stops.select { |stop| stop.kind == 'visit' && stop.active != false && stop.sync_state == 'active' }
    visits.each do |stop|
      snap = stop.visit_snapshot.except('deliveries', 'pickups')
      snap = { 'id' => stop.id } if snap.blank?
      stop.update_columns(visit_snapshot: snap)
    end

    unit = route.reload.board[:units].find { |row| row[:id] == '9' }
    assert unit
    assert_equal 2.0 * visits.size, unit[:delivery]
    assert_equal 1.0 * visits.size, unit[:pickup]
    assert_equal 0.0, unit[:collected]
  end

  test 'publish keeps address and quantities after planning and destination wipe' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    stop = operation.operation_stops.joins(:visit).find_by!(visit_id: visits(:visit_two).id)
    assert_equal 'destination_two', stop.destination_snapshot['name']
    assert_equal 3.0, stop.visit_snapshot.dig('deliveries', '1', 'value')
    assert_equal 'L', stop.visit_snapshot.dig('deliveries', '1', 'label')
    refute stop.operation_route.vehicle_snapshot.key?('driver_token')
    locales = stop.operation_route.vehicle_snapshot['router_name_locale']
    assert_equal 'Router fr', locales['fr']
    assert_equal 'Router en', locales['en']
    I18n.with_locale(:en) { assert_equal 'Router en', stop.operation_route.router_name }
    I18n.with_locale(:fr) { assert_equal 'Router fr', stop.operation_route.router_name }

    @customer.delete_all_plannings
    @customer.delete_all_destinations

    stop.reload
    assert_nil stop.destination_id
    assert_nil stop.visit_id
    assert_nil stop.operation_route.operation.planning_id
    assert_equal 'destination_two', stop.destination_snapshot['name']
    assert_equal 3.0, stop.visit_snapshot.dig('deliveries', '1', 'value')
  end

  test 'a later operation does not inherit status or photos' do
    first = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 25))
    planning_stop = stops(:stop_one_one)
    planning_stop.photos.purge if planning_stop.photos.attached?
    planning_stop.signature.purge if planning_stop.signature.attached?
    owned = first.operation_stops.find_by!(stop_id: planning_stop.id)
    OperationStops::RecordStatus.call(
      operation_stop: owned,
      status: 'delivered',
      recorded_at: Time.zone.parse('2026-09-25 11:00'),
      source: 'mobile'
    )
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
    assert owned.attach_photos([file])
    file.rewind if file.respond_to?(:rewind)
    planning_stop.attach_signature(file)

    first.update!(status: 'historized', closed_at: Time.current)
    second = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 26))
    other = second.operation_stops.find_by!(stop_id: planning_stop.id)

    assert_equal 'delivered', owned.reload.status
    assert owned.photos.attached?
    assert_nil other.status
    assert_not other.photos.attached?
    assert_not other.signature.attached?
    photo = owned.document_items.find { |item| item[:kind] == 'photo' }
    assert_includes photo[:url], '/stop_photos/'
    # Later operation owns no proofs; planning-stop signature may still appear via document_items.
    assert_equal [{ kind: 'signature' }], other.document_items.map { |item| item.slice(:kind) }
    assert_nil planning_stop.reload.status
  ensure
    owned&.photos&.purge
    planning_stop&.signature&.purge
  end

  test 'two dates keep the same planning stop and route ids' do
    first = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 25))
    first.update!(status: 'historized', closed_at: Time.current)
    second = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 26))

    stop_id = stops(:stop_one_one).id
    route_id = routes(:route_one_one).id
    assert first.operation_stops.exists?(stop_id: stop_id)
    assert second.operation_stops.exists?(stop_id: stop_id)
    assert first.operation_routes.exists?(route_id: route_id)
    assert second.operation_routes.exists?(route_id: route_id)
  end

  test 'parallel publish keeps disjoint open operations' do
    route_a = routes(:route_one_one)
    route_b = routes(:route_three_one)
    first = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Matin',
      date: Date.new(2026, 9, 25),
      route_ids: [route_a.id]
    )
    second = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Aprem',
      date: Date.new(2026, 9, 25),
      route_ids: [route_b.id]
    )

    assert_equal 'in_progress', first.status
    assert_equal 'in_progress', second.status
    assert_equal 'Matin', first.name
    assert_equal 'Aprem', second.name
    assert_equal [route_a.id], first.operation_routes.pluck(:route_id)
    assert_equal [route_b.id], second.operation_routes.pluck(:route_id)
    assert_equal 2, @planning.open_operations.count
  end

  test 'publish rejects a route already in an open operation on the same date' do
    route_id = routes(:route_one_one).id
    Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 25), route_ids: [route_id])

    error = assert_raises(Operations::RouteConflict) do
      Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 25), route_ids: [route_id])
    end
    assert_includes error.route_ids, route_id
  end

  test 'publish allows the same route on a different date while the first stays open' do
    route_id = routes(:route_one_one).id
    first = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 25), route_ids: [route_id])
    second = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 26), route_ids: [route_id])

    assert_equal 'in_progress', first.status
    assert_equal 'in_progress', second.status
    assert_equal Date.new(2026, 9, 25), first.date
    assert_equal Date.new(2026, 9, 26), second.date
  end

  test 'changing an open operation date fails when a route is already taken that day' do
    route_id = routes(:route_one_one).id
    Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 25), route_ids: [route_id])
    other = Operations::PublishFromPlanning.call(planning: @planning, date: Date.new(2026, 9, 26), route_ids: [route_id])

    assert_not other.update(date: Date.new(2026, 9, 25))
    assert_includes other.errors[:base], I18n.t('operations.show.route_date_conflict')
  end

  test 'publish with an empty route selection fails' do
    assert_raises(Operations::EmptyRoutes) do
      Operations::PublishFromPlanning.call(planning: @planning, route_ids: [])
    end
  end

  test 'sync refreshes snapshots without touching status events or the cursor' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    stop = operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    recorded_at = Time.zone.parse('2026-09-25 10:00')
    OperationStops::RecordStatus.call(operation_stop: stop, status: 'delivered', recorded_at: recorded_at, source: 'mobile')
    destinations(:destination_one).update_columns(name: 'Renamed place')

    Operations::SyncFromPlanning.call(planning: @planning.reload, operation: operation.reload)
    stop.reload
    assert_equal 'Renamed place', stop.destination_snapshot['name']
    assert_equal 'delivered', stop.status
    assert_equal 1, stop.operation_stop_status_events.count
  end

  test 'partial sync does not refresh stops outside the route scope' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    outside = operation.operation_stops.find_by!(visit_id: visits(:visit_two).id)
    original = outside.destination_snapshot['name']
    destinations(:destination_two).update_columns(name: 'Should stay')

    Operations::SyncFromPlanning.call(
      planning: @planning.reload,
      operation: operation,
      route_ids: [routes(:route_three_one).id]
    )
    assert_equal original, outside.reload.destination_snapshot['name']
  end

  test 'sync targets the given operation among several open ones' do
    route_a = routes(:route_one_one)
    route_b = routes(:route_three_one)
    first = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_a.id])
    second = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_b.id])
    stop = first.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    destinations(:destination_one).update_columns(name: 'Synced place')

    Operations::SyncFromPlanning.call(planning: @planning.reload, operation: first.reload)
    assert_equal 'Synced place', stop.reload.destination_snapshot['name']
    assert_equal 'in_progress', second.reload.status
  end

  test 'sync marks a deleted stop orphaned and keeps its events' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    stop = operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    OperationStops::RecordStatus.call(operation_stop: stop, status: 'started', recorded_at: Time.zone.parse('2026-09-25 09:00'), source: 'mobile')
    planning_stop_id = stop.stop_id
    Stop.where(id: planning_stop_id).delete_all

    Operations::SyncFromPlanning.call(planning: @planning.reload, operation: operation.reload)
    stop.reload
    assert_equal 'orphaned', stop.sync_state
    assert_equal 1, stop.operation_stop_status_events.count
    assert_equal 'started', stop.status
  end
end
