# frozen_string_literal: true

require 'test_helper'

class DeliverDemoTickTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @customer.update!(devices: { deliver: { enable: true, demo: true } })
    @customer.users.order(:id).first.update_columns(time_zone: 'Paris')
    @operation = Operations::PublishFromPlanning.call(
      planning: @planning,
      route_ids: [routes(:route_one_one).id]
    )
    @route = @operation.operation_routes.find_by!(route_id: routes(:route_one_one).id)
    @stops = @route.operation_stops.executable.order(:index).to_a
    tracks = @stops.map.with_index { |stop, position|
      base_lng = 2.35 + (position * 0.1)
      base_lat = 48.85 + (position * 0.1)
      {
        'stop_index' => stop.index,
        # Multipolyline: two segments between previous point and this stop.
        'coordinates' => [
          [[base_lng, base_lat], [base_lng + 0.02, base_lat + 0.01]],
          [[base_lng + 0.02, base_lat + 0.01], [base_lng + 0.04, base_lat + 0.02]]
        ]
      }
    }
    snap = @route.route_snapshot.merge(
      'tracks' => tracks,
      'start' => 8 * 3600,
      'end' => 18 * 3600
    )
    @route.update_columns(route_snapshot: snap)
    @stops.each_with_index do |stop, index|
      seconds = (9 * 3600) + (index * 3600)
      attrs = { stop_snapshot: stop.stop_snapshot.merge('time' => seconds) }
      if stop.visit?
        attrs[:visit_snapshot] = (stop.visit_snapshot || {}).merge('duration' => 2 * 3600) # huge on purpose: must be capped
      end
      stop.update_columns(attrs)
    end
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'tick records a position on the first stop multipolyline with planned positioned_at' do
    cursors, done = DeliverDemo::Tick.call(operation: @operation, cursors: {})
    refute done

    position = @route.vehicle_positions.order(:id).last
    assert position
    assert_equal 'demo', position.source
    first_leg = @route.route_snapshot['tracks'].first['coordinates'].flatten(1)
    lngs = first_leg.map(&:first)
    lats = first_leg.map(&:last)
    assert position.lng.between?(lngs.min, lngs.max)
    assert position.lat.between?(lats.min, lats.max)

    Time.use_zone('Paris') do
      day_start = Time.zone.local(@operation.date.year, @operation.date.month, @operation.date.day)
      assert position.positioned_at >= day_start + (8 * 3600)
      assert position.positioned_at <= day_start + (18 * 3600)
    end

    assert_equal 'finished', @route.reload.departure_status
    visit = @stops.find(&:visit?)
    assert_equal 'intransit', visit.reload.status if visit
  end

  test 'tick stays on the current stop multipolyline until the stop is treated' do
    first_stop = @stops.first
    first_leg = @route.route_snapshot['tracks'].find { |t| t['stop_index'] == first_stop.index }['coordinates'].flatten(1)
    lngs = first_leg.map(&:first)
    lats = first_leg.map(&:last)

    cursors = {}
    DeliverDemo::Tick::STEPS_PER_LEG.times do
      cursors, = DeliverDemo::Tick.call(operation: @operation, cursors: cursors)
      position = @route.vehicle_positions.order(:id).last
      assert position.lng.between?(lngs.min - 0.0001, lngs.max + 0.0001)
      assert position.lat.between?(lats.min - 0.0001, lats.max + 0.0001)
      break if first_stop.reload.treated?
    end
  end

  test 'tick finishes a visit with delivered and recorded_at close to planned_at' do
    cursors = {}
    done = false
    80.times do
      cursors, done = DeliverDemo::Tick.call(operation: @operation, cursors: cursors)
      break if done || @stops.any? { |s| %w[delivered finished].include?(s.reload.status.to_s) }
    end

    finished = @stops.find { |s| %w[delivered finished].include?(s.reload.status.to_s) }
    assert finished, 'expected at least one treated stop'
    assert_equal 'demo', finished.operation_stop_status_events.order(:id).last.source

    if finished.visit?
      assert_equal 'delivered', finished.status
      refute finished.operation_stop_status_events.exists?(status: 'started')
      assert finished.operation_stop_status_events.exists?(status: 'intransit')
    end

    Time.use_zone('Paris') do
      planned_arrival = finished.planned_at
      finish_event = finished.operation_stop_status_events.order(:id).to_a.reverse.find { |e|
        %w[delivered finished].include?(e.status.to_s)
      }
      assert finish_event
      # Demo caps on-site service; finish ≈ planned arrival + capped service (± jitter).
      slack = DeliverDemo::Tick::MAX_SERVICE_SECONDS + DeliverDemo::Tick::JITTER_SECONDS + 1
      assert_in_delta (planned_arrival + DeliverDemo::Tick::MAX_SERVICE_SECONDS).to_i, finish_event.recorded_at.to_i, slack
      # Delay is vs planned departure — align snapshot duration with the capped service used above.
      if finished.visit?
        finished.update_columns(visit_snapshot: finished.visit_snapshot.merge('duration' => DeliverDemo::Tick::MAX_SERVICE_SECONDS))
      end
      assert finished.delay_minutes.abs <= (DeliverDemo::Tick::JITTER_SECONDS / 60) + 1
    end
  end

  test 'tick emits several position updates before treating the first stop' do
    cursors = {}
    positions_before_treated = 0
    DeliverDemo::Tick::STEPS_PER_LEG.times do
      cursors, = DeliverDemo::Tick.call(operation: @operation, cursors: cursors)
      positions_before_treated = @route.vehicle_positions.count
      break if @stops.any? { |s| s.reload.treated? }
    end

    assert positions_before_treated >= DeliverDemo::Tick::STEPS_PER_LEG - 1
  end

  test 'tick writes planned-local times even when the worker Time.zone is UTC' do
    visit = @stops.find(&:visit?)
    assert visit

    Time.use_zone('UTC') do
      cursors = {}
      80.times do
        cursors, done = DeliverDemo::Tick.call(operation: @operation, cursors: cursors)
        break if done || visit.reload.treated?
      end
    end

    finish_event = visit.operation_stop_status_events.order(:id).to_a.reverse.find { |e|
      %w[delivered finished].include?(e.status.to_s)
    }
    assert finish_event
    Time.use_zone('Paris') do
      planned_arrival = visit.planned_at
      slack = DeliverDemo::Tick::MAX_SERVICE_SECONDS + DeliverDemo::Tick::JITTER_SECONDS + 1
      assert_in_delta (planned_arrival + DeliverDemo::Tick::MAX_SERVICE_SECONDS).to_i, finish_event.recorded_at.to_i, slack
      assert_in_delta (planned_arrival + DeliverDemo::Tick::MAX_SERVICE_SECONDS).hour, finish_event.recorded_at.in_time_zone('Paris').hour, 1
    end
  end

  test 'tick skips drive steps when the stop-to-stop path has zero length' do
    visit = @stops.find(&:visit?)
    assert visit
    point = [visit.lng.to_f, visit.lat.to_f]
    tracks = @stops.map { |stop|
      {
        'stop_index' => stop.index,
        'coordinates' => [point, point.dup]
      }
    }
    @route.update_columns(route_snapshot: @route.route_snapshot.merge('tracks' => tracks))

    cursors, = DeliverDemo::Tick.call(operation: @operation, cursors: {})

    assert visit.reload.treated?, 'zero-length leg should treat the stop in one tick'
    assert_equal 'delivered', visit.status if visit.visit?
    # Chained into the next stop (or finished) without waiting STEPS_PER_LEG jobs.
    assert_operator cursors.fetch(@route.id.to_s).fetch('stop_index').to_i, :>=, 1
  end

  test 'tick does not leave visits stuck intransit when planned times overlap' do
    # Same planned time + long previous service would make finish < intransit without a clamp.
    @stops.each do |stop|
      stop.update_columns(stop_snapshot: stop.stop_snapshot.merge('time' => 10 * 3600))
    end
    visits = @stops.select(&:visit?)
    assert visits.size >= 2

    cursors = {}
    120.times do
      cursors, done = DeliverDemo::Tick.call(operation: @operation, cursors: cursors)
      break if done
    end

    stuck = visits.select { |stop| stop.reload.status.to_s == 'intransit' }
    assert_empty stuck.map(&:id), 'expected no visit left as intransit after demo run'
    assert visits.all? { |stop| stop.reload.treated? }
  end

  test 'negative jitter is clamped to the planned leg duration' do
    tick = DeliverDemo::Tick.new(@operation, {})
    visit = @stops.find(&:visit?)
    assert visit
    stop_index = @stops.index(visit)

    tick.stubs(:random_jitter_seconds).returns(-DeliverDemo::Tick::JITTER_SECONDS)
    tick.stubs(:planned_leg_seconds).returns(90)
    offset = tick.send(:sample_offset_seconds, @route, @stops, stop_index)
    assert_equal(-90, offset)
  end

  test 'tick finishes store reloads as finished not delivered' do
    visit = @stops.find(&:visit?)
    assert visit
    store = stores(:store_one)
    reload_stop = @route.operation_stops.create!(
      kind: 'store',
      index: visit.index + 50,
      sync_state: 'active',
      active: true,
      store: store,
      store_snapshot: { 'name' => store.name, 'lat' => store.lat, 'lng' => store.lng, 'duration' => 60 },
      stop_snapshot: { 'time' => 16 * 3600 }
    )
    @stops = @route.operation_stops.executable.order(:index).to_a
    tracks = @stops.map.with_index { |stop, position|
      base_lng = 2.35 + (position * 0.1)
      base_lat = 48.85 + (position * 0.1)
      {
        'stop_index' => stop.index,
        'coordinates' => [
          [[base_lng, base_lat], [base_lng + 0.001, base_lat + 0.001]],
          [[base_lng + 0.001, base_lat + 0.001], [base_lng + 0.002, base_lat + 0.002]]
        ]
      }
    }
    @route.update_columns(route_snapshot: @route.route_snapshot.merge('tracks' => tracks))

    cursors = {}
    120.times do
      cursors, done = DeliverDemo::Tick.call(operation: @operation, cursors: cursors)
      break if done || reload_stop.reload.treated?
    end

    assert_equal 'finished', reload_stop.reload.status
    refute_equal 'delivered', reload_stop.status
    assert reload_stop.operation_stop_status_events.exists?(status: 'atstore')
    assert reload_stop.operation_stop_status_events.exists?(status: 'finished')
    refute reload_stop.operation_stop_status_events.exists?(status: 'delivered')
  end
end
