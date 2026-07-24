require 'test_helper'
require 'routers/osrm'

class RouteTest < ActiveSupport::TestCase

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 720, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        yield
      end
    end
  end

  test 'should not save' do
    route = Route.new
    assert_not route.save, 'Saved without required fields'
  end

  test 'max_loads returns per deliverable unit peaks from route_data baseline and stop loads' do
    route = routes(:route_one_one)
    route.compute_saved!
    route.stops.load
    ml = route.max_loads
    ml_with_arg = route.max_loads
    assert_equal ml, ml_with_arg
    route.planning.customer.deliverable_units.each do |du|
      next unless ml.key?(du.id)

      assert_operator ml[du.id], :>=, route.deliveries[du.id] || 0
    end
  end

  test 'merge_stop_leg_alerts_into_route_data combines final leg route alerts' do
    route = routes(:route_one_one)
    route_data_attributes = { out_of_work_time: false, out_of_drive_time: false, no_path: false }
    route_attributes = {
      stop_out_of_work_time: true,
      stop_out_of_drive_time: false,
      stop_no_path: true,
      stop_out_of_max_distance: false
    }

    route.send(:merge_stop_leg_alerts_into_route_data!, route_data_attributes, route_attributes)

    assert route_data_attributes[:out_of_work_time]
    assert_not route_data_attributes[:out_of_drive_time]
    assert route_data_attributes[:no_path]
  end

  test 'merge_stop_leg_alerts_into_route_data defaults nil alert fields to false' do
    route = routes(:route_one_one)
    route_data_attributes = {}
    route_attributes = {
      stop_out_of_work_time: nil,
      stop_out_of_drive_time: nil,
      stop_no_path: nil,
      stop_out_of_max_distance: nil
    }

    route.send(:merge_stop_leg_alerts_into_route_data!, route_data_attributes, route_attributes)

    assert_equal false, route_data_attributes[:no_path]
    assert_equal false, route_data_attributes[:out_of_drive_time]
  end

  test 'out_of_max_ride_distance is stored on route_data and resets on recompute' do
    route = routes(:route_one_one)
    vehicle = route.vehicle_usage.vehicle

    vehicle.update_columns(max_ride_distance: 500)
    route.vehicle_usage.vehicle.reload
    route.outdated = true
    route.compute_saved!
    route.reload

    assert route.out_of_max_ride_distance
    assert route.route_data.out_of_max_ride_distance
    assert route.stops.any?(&:out_of_max_ride_distance)

    vehicle.update_columns(max_ride_distance: nil)
    route.vehicle_usage.vehicle.reload
    route.outdated = true
    route.compute_saved!
    route.reload

    assert_not route.out_of_max_ride_distance
    assert_not route.route_data.out_of_max_ride_distance
    assert route.stops.none?(&:out_of_max_ride_distance)
  end

  test 'total_duration includes rests_duration' do
    route = routes(:route_three_one)
    route.route_data.update_columns(rests_duration: 2700, visits_duration: 100, wait_time: 50, drive_time: 200)

    expected = 2700 + 100 + 50 + 200 +
               route.vehicle_usage.default_service_time_start.to_i +
               route.vehicle_usage.default_service_time_end.to_i

    assert_equal expected, route.total_duration
  end

  test 'route work_duration and total_duration include service times route_data does not' do
    route = routes(:route_three_one)
    route.route_data.update_columns(rests_duration: 2700, visits_duration: 100, wait_time: 50, drive_time: 200)
    vu = route.vehicle_usage
    service = vu.default_service_time_start.to_i + vu.default_service_time_end.to_i

    assert_equal 350, route.route_data.work_duration
    assert_equal 3050, route.route_data.duration
    assert_equal 350 + service, route.work_duration
    assert_equal 3050 + service, route.total_duration
    assert_equal route.route_data.work_duration + service, route.work_duration
    assert_equal route.route_data.duration + service, route.total_duration
  end

  test 'work_duration excludes rests_duration from total_duration' do
    route = routes(:route_three_one)
    route.route_data.update_columns(rests_duration: 2700, visits_duration: 100, wait_time: 50, drive_time: 200)

    assert_equal route.total_duration - 2700, route.work_duration
  end

  test 'plan clears rests_duration on route_data when rest stop is inactive' do
    route = routes(:route_three_one)
    route.route_data.update_column(:rests_duration, 2700)
    route.start_route_data.update_column(:rests_duration, 2700)

    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    rest.update_column(:active, false)

    route.compute_saved!
    route.reload

    assert_equal 0, route.route_data.rests_duration
    assert_equal 0, route.start_route_data.rests_duration
  end

  test 'compute_saved! persists computed metrics on route_data for snapshot reads when not outdated' do
    route = routes(:route_one_one)
    route.route_data.distance = route.route_data.emission = route.route_data.start = route.route_data.end = nil
    route.outdated = true
    route.compute_saved!
    route.reload
    expected_stops = Stop.where(route_id: route.id).count
    assert_equal expected_stops, route.route_data.stops_size
    assert_equal expected_stops, route.stops_size
    assert_kind_of Hash, route.route_data.max_loads
  end

  test 'compute_saved! persists stops_size and count metrics on route_data for unscheduled route' do
    route = routes(:route_zero_one)
    assert_not route.vehicle_usage?
    route.outdated = true
    route.compute_saved!
    route.reload
    expected_stops = Stop.where(route_id: route.id).count
    assert_equal expected_stops, route.route_data.stops_size
    assert_equal expected_stops, route.stops_size
    assert_equal route.stops.count(&:active), route.route_data.size_active
  end

  test 'compute_saved! persists stop count metrics on route_data for vehicle route without StopVisit' do
    route = routes(:route_one_one)
    assert route.vehicle_usage?

    Route.transaction do
      route.stops.where(type: StopVisit.name).delete_all
      route.reload
      assert_operator route.stops.size, :>=, 1
      assert(route.stops.none? { |s| s.is_a?(StopVisit) })

      route.outdated = true
      route.compute_saved!
      route.reload

      assert_equal route.stops.size, route.route_data.stops_size
      assert_equal route.stops.count(&:active), route.route_data.size_active
      assert_equal 0, route.route_data.size_destinations

      raise ActiveRecord::Rollback
    end
  end

  test 'should save without loading stops' do
    route = routes(:route_one_one)
    assert route.update(outdated: true)
    assert_not route.stops.loaded?
  end

  test 'should default_stops' do
    route = routes(:route_one_one)
    route.planning.tags.clear
    route.stops.clear
    route.save!
    assert_difference('Stop.count', Visit.joins(:destination).where(destinations: {customer_id: route.planning.customer_id}).count + (route.rest? ? 1 : 0)) do
      route.default_stops
      route.save!
    end
  end

  test 'should compute' do
    route = routes(:route_one_one)
    route.route_data.distance = route.route_data.emission = route.route_data.start = route.route_data.end = nil
    route.outdated = true
    route.compute_saved
    assert_not route.outdated
    assert route.distance
    assert route.emission
    assert route.start
    assert route.end
    assert_nil route.revenue
    assert_equal 50.0, route.cost_fixed
    assert_equal route.cost_distance, route.vehicle_usage.cost_distance * (route.distance.to_f / 1000)
    assert_equal route.cost_time, route.vehicle_usage.cost_time * ((route.end - route.start).to_f / 3600)
    assert_equal 1000 * (route.stops.size + 1), route.distance
  end

  test 'compute applies vehicle duration coefficients to visits_duration' do
    route = routes(:route_one_one)
    vehicle_usage = route.vehicle_usage

    route.stops.select{ |s| s.is_a?(StopVisit) }.each do |stop|
      stop.visit.destination.update_columns(duration: 60)
    end

    vehicle_usage.update!(visit_duration_coef: 1, destination_duration_coef: 1)
    route.outdated = true
    route.compute_saved!
    base_visits_duration = route.visits_duration

    vehicle_usage.update!(visit_duration_coef: 2, destination_duration_coef: 2)
    route.outdated = true
    route.compute_saved!

    assert_equal base_visits_duration * 2, route.visits_duration
  end

  test 'should compute empty' do
    route = routes(:route_one_one)
    assert route.stops.size > 1
    route.outdated = true
    route.compute_saved
    assert_equal 1000 * (route.stops.size + 1), route.distance

    route.stops.each{ |stop|
      stop.active = false
    }

    route.outdated = true
    route.compute_saved
    assert_equal 1000.0, route.distance
  end

  test 'should set visits' do
    route = routes(:route_one_one)
    route.stops.clear
    assert_difference('Stop.count', 2) do
      # Set one visit in addition of the rest automatically added
      route.set_visits([[visits(:visit_two), true]])
      route.save!
    end
  end

  test 'add_objects places auto rest at end when rest is not imported' do
    route = routes(:route_one_one)
    route.set_objects([[visits(:visit_two), { active: true }]], false)
    route.save!
    route.stops.reload

    assert_equal visits(:visit_two), route.stops.first.visit
    assert_kind_of StopRest, route.stops.last
    assert_equal route.stops.size, route.stops.last.index
  end

  test 'add_objects keeps imported rest at provided index' do
    route = routes(:route_one_one)
    route.set_objects([
      [visits(:visit_two), { active: true, index: 1 }],
      [:rest, { active: true, index: 2 }],
      [visits(:visit_one), { active: true, index: 3 }]
    ], false)
    route.save!
    route.stops.reload

    assert_equal visits(:visit_two), route.stops[0].visit
    assert_kind_of StopRest, route.stops[1]
    assert_equal visits(:visit_one), route.stops[2].visit
  end

  test 'should add' do
    route = routes(:route_zero_one)
    route.add(visits(:visit_two))
    route.save!
    route.reload
    assert route.stops.collect(&:visit).include?(visits(:visit_two))
  end

  test 'should add index' do
    route = routes(:route_one_one)
    route.add(visits(:visit_two), 1)
    route.save!
    route.stops.reload
    assert_equal visits(:visit_two), route.stops.find{ |s| s.visit.destination.name == 'destination_two' }.visit
  end

  test 'should add without index' do
    route = routes(:route_one_one)
    route.add(visits(:visit_two))
    route.save!
    route.stops.reload
    assert_equal visits(:visit_two), route.stops.find{ |s| s.visit.destination.name == 'destination_two' }.visit
  end

  test 'should remove visit' do
    route = routes(:route_one_one)
    assert_difference('Stop.count', -1) do
      assert route.remove_visit(visits(:visit_two)), 'Should return a value'
      route.save!
    end
  end

  test 'should not remove visit' do
    route = routes(:route_one_one)
    assert_difference('Stop.count', 0) do
      assert_nil route.remove_visit(visits(:visit_unaffected_one))
      route.save!
    end
  end

  test 'should sum_out_of_window' do
    route = routes(:route_one_one)

    route.stops.each { |stop|
      if stop.is_a?(StopVisit)
        stop.visit.time_window_start_1 = stop.visit.time_window_end_1 = nil
        stop.visit.time_window_start_2 = stop.visit.time_window_end_2 = nil
        stop.visit.save!
      else
        stop.time = stop.time_window_start_1
        stop.save!
      end
    }
    route.vehicle_usage.time_window_start = 0
    route.planning.customer.visit_duration = 0
    route.planning.customer.save!

    assert_equal 0, route.sum_out_of_window

    route.stops[1].visit.time_window_start_1 = 0
    route.stops[1].visit.time_window_end_1 = 0
    route.stops[1].visit.save!
    assert_equal 30, route.sum_out_of_window
  end

  test 'should change active' do
    route = routes(:route_one_one)

    assert_equal 4, route.size_active
    route.active(:none)
    route.compute_saved!
    assert_equal 0, route.size_active
    route.active(:all)
    route.compute_saved!
    assert_equal 4, route.size_active
    route.stops[0].active = false
    route.compute_saved!
    assert_equal 3, route.size_active
    route.active(:foo_bar)
    route.compute_saved!
    assert_equal 0, route.size_active
  end

  test 'size_active_destinations is zero when no active visit stops' do
    route = routes(:route_one_one)
    route.active(:none)
    route.compute_saved!
    assert_equal 0, route.size_active_destinations
  end

  test 'size_active_destinations reflects active stops without recompute' do
    route = routes(:route_one_one)
    route.stops.where(type: 'StopVisit').update_all(active: false)
    route.stops.order(:index).find_by(type: 'StopVisit').update!(active: true)
    route.reload
    route.association(:stops).reset

    assert_equal 1, route.size_active_destinations
  end

  test 'should reverse stops' do
    route = routes(:route_one_one)
    ids = route.stops.collect(&:id)
    route.reverse_order
    assert_equal ids, route.stops.collect(&:id)
  end

  test 'compute route with impossible path' do
    route = routes(:route_one_one)
    route.stops[1].visit.destination.lat = route.stops[1].visit.destination.lng = 1 # Geocoded
    route.save!
    route.stops[1].distance = nil
    route.save!
    route.stop_distance = nil
    route.save!
    stop = route.vehicle_usage.store_stop
    stop.lat = stop.lng = 1 # Geocoded
    stop.save!
    route.outdated = true
    route.compute_saved
  end

  test 'should shift departure' do
    route = routes(:route_one_one)

    stops = route.stops.select{ |s| s.is_a?(StopVisit) }
    stops[0].time = '10:30:00'
    stops[0].visit.time_window_start_1 = '11:00:00'
    stops[0].visit.time_window_end_1 = '11:30:00'
    stops[1].time = '11:00:00'
    stops[1].visit.time_window_start_1 = '10:00:00'
    stops[1].visit.time_window_end_1 = '11:30:00'
    stops[2].time = '11:30:00'
    stops[2].visit.time_window_start_1 = '12:00:00'
    stops[2].visit.time_window_end_1 = '14:00:00'

    route.outdated = true
    route.compute_saved
    assert_equal Time.parse('10:55:27').seconds_since_midnight.to_i, route.start
  end

  test 'should get default color' do
    route = routes(:route_one_one)
    route.color = nil

    assert_not_nil route.default_color

    route.color = '#plop'
    assert_equal route.color, route.default_color
  end

  test 'should update route color' do
    o = routes(:route_one_one)
    o.update! color: '#123123' # Some visits are tagged with #FF0000
    features = JSON.parse('[' + ((o.geojson_tracks || []) + (o.geojson_points || [])).join(',') + ']')
    assert_equal ['#123123', '#FF0000'], features.map{ |f| f['properties']['color'] }.uniq.compact
  end

  test 'should output as geojson' do
    o = routes(:route_one_one)

    # polyline & respect_hidden
    o.hidden = false
    assert_not o.hidden
    geojson = JSON.parse(o.to_geojson(true, true, :polyline))
    assert geojson['features'].size > 0
    assert geojson['features'].one?{ |feature| feature['geometry']['polylines'] }

    # polyline & don't respect_hidden
    o.hidden = true
    assert o.hidden
    geojson = o.to_geojson(false, true, :polyline)
    assert_equal geojson, '{"type":"FeatureCollection","features":[]}'

    # coordinates & respect_hidden
    o.hidden = false
    assert_not o.hidden
    geojson = JSON.parse(o.to_geojson(false, true, true))
    assert geojson['features'].size > 0
    assert geojson['features'].one?{ |feature| feature['geometry']['coordinates'] && feature['geometry']['type'] == 'LineString' }

    # coordinates & don't respect_hidden
    o.hidden = true
    assert o.hidden
    geojson = o.to_geojson(false, true, true)
    assert_equal geojson, '{"type":"FeatureCollection","features":[]}'
  end

  test 'should set time for all stops after plan' do
    # Store start without geo
    o = routes(:route_three_one)
    # Move rest at first position
    o.move_stop(o.stops.find{ |s| s.is_a?(StopRest) }, 1)

    o.plan
    o.stops.each { |stop|
      assert stop.time
    }
  end

  test 'plan shifts unpositioned stop_rest start earlier when rest window is violated' do
    route = routes(:route_one_one)
    route.vehicle_usage.update_columns(store_rest_id: nil)
    route.planning.customer.update_columns(enable_strict_within_timewindows: true)

    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    route.move_stop(rest, 2)
    route.save!
    route.reload

    departure = 48_700
    route.route_data.update_columns(departure: departure)
    route.outdated = true
    route.compute_saved!
    route.reload

    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    prev_stop = route.stops.sort_by(&:index).find { |stop| stop.index < rest.index && stop.active? }
    next_stop = route.stops.sort_by(&:index).find { |stop| stop.index > rest.index && stop.active? }

    materialized_arrival = prev_stop.time + prev_stop.duration + (rest.drive_time || 0)
    strict = route.planning.customer.enable_strict_within_timewindows
    _open, close, = rest.best_open_close(materialized_arrival, strict_within_timewindows: strict)
    close_compare_time = strict ? materialized_arrival + rest.duration : materialized_arrival
    lateness = close && close_compare_time > close ? close_compare_time - close : 0
    shift = [lateness, rest.drive_time].compact.min

    assert_operator lateness, :>, 0
    assert_operator shift, :>, 0
    assert_equal materialized_arrival - shift, rest.time
    assert_not rest.out_of_window
    assert_nil rest.wait_time
    assert_equal materialized_arrival + rest.duration + next_stop.drive_time, next_stop.time
  end

  test 'should return the drive time when compute' do
    route = routes(:route_one_one)
    route.compute_saved!
    total_drive_time = route.stops.map(&:drive_time).sum(0) # Total stops drive time
    total_drive_time += route.stop_drive_time # The last stop (in case of store)
    assert_equal total_drive_time, route.route_data.drive_time # ensure compute, computed all stops drive time
  end

  test 'should return the waiting time when compute' do
    route = routes(:route_one_one)
    route.compute_saved!
    total_wait_time = route.stops.map(&:wait_time).sum(0) { |wait_time| wait_time || 0 }
    assert_equal route.wait_time, total_wait_time
  end

  test 'should reset all value to nil when deleting all stops' do
    route = routes(:route_one_one)
    route.planning.customer.delete_all_destinations
    route.reload
    assert_nil route.wait_time
    assert_nil route.drive_time
    assert_nil route.visits_duration
  end

  test 'should compute quantities and let the last stop capable' do
    route = routes(:route_one_one)
    kg = deliverable_units(:deliverable_unit_one_two)

    capacities = {}
    capacities[kg.id] = 5

    route.vehicle_usage.vehicle.capacities = capacities
    route.vehicle_usage.vehicle.save!
    route.reload

    visits = route.stops.collect { |s| s.visit if s.is_a?(StopVisit) }.compact

    capacities[kg.id] = 6
    visits.second.deliveries = capacities
    visits.last.deliveries = {}

    route.compute_saved({no_geojson: true})
    stops_capacities = route.stops.map(&:out_of_capacity)

    # First stop is out_of_capacity due to init load which is the sum of all the requested deliveries
    assert_equal true, stops_capacities[0]
    # Second stop is out_of_capacity due to previous set up
    assert_equal true, stops_capacities[1]
    # Last stop must be false, it doesnt deliver "kg" so it's not affected
    assert_equal false, stops_capacities[2]
  end

  test 'should set stops as unmanageable capacity' do
    route = routes(:route_one_one)
    route.vehicle_usage.vehicle.capacities[1] = 0.0
    route.compute_loads

    route.stops.each { |s|
      if s.is_a?(StopVisit) && s.visit.deliveries.key?(1)
        assert !!s.unmanageable_capacity
      end
    }
  end

  test 'should not set stops as unmanageable capacity' do
    route = routes(:route_one_one)
    route.vehicle_usage.vehicle.capacities[1] = nil
    route.compute_loads

    route.stops.each { |s|
      if s.is_a?(StopVisit) && s.visit.deliveries.key?(1)
        assert_not !!s.unmanageable_capacity
      end
    }
  end

  test 'should detect the unmet force_position' do
    route = routes(:route_one_one)

    route.compute_out_of_force_position
    assert route.stops.none?(&:out_of_force_position)

    always_first_visit = route.stops.find{ |stop| stop.index == 2 }.visit
    always_first_visit.force_position = :always_first

    route.compute_out_of_force_position
    assert route.stops.one?(&:out_of_force_position)

    route.outdated = true
    route.compute
    assert route.stops.one?(&:out_of_force_position)

    always_first_visit.force_position = :neutral
    route.outdated = true
    route.compute_saved
    assert route.stops.none?(&:out_of_force_position)
  end

  test 'should add sub_tour_index to polylines when route has StopStore' do
    route = routes(:route_one_one)
    customer = route.planning.customer
    customer.update(enable_store_stops: true)

    # Add a StopStore to create a sub-tour
    store = stores(:store_one)
    route.vehicle_usage.update(max_reload: 1)
    store_reload = store.store_reloads.create!(ref: 'SR001')
    route.add_store_reload(store_reload)

    # Compute the route to generate polylines
    route.outdated = true
    route.compute_saved!

    # Check that polylines have sub_tour_index property
    if route.geojson_tracks && route.geojson_tracks.any?

      stop_store_index = route.stops.index{ |stop| stop.type == "StopStore" }
      route.geojson_tracks.each.with_index do |track_json, index|
        break if index >= stop_store_index

        track = JSON.parse(track_json)
        if track['geometry'] && track['geometry']['polylines']
          assert track['properties'].key?('sub_tour_index'), 'Polyline should have sub_tour_index property'
          assert_equal 0, track['properties']['sub_tour_index'], 'First sub-tour should have index 0'
        end
      end
    end
  end

  test 'should increment sub_tour_index after each StopStore' do
    route = routes(:route_one_one)
    customer = route.planning.customer
    customer.update(enable_store_stops: true)

    store = stores(:store_one)
    route.vehicle_usage.update(max_reload: 2)
    store_reload1 = store.store_reloads.create!(ref: 'SR001')
    store_reload2 = store.store_reloads.create!(ref: 'SR002')

    route.add_store_reload(store_reload1)
    route.add_store_reload(store_reload2)

    route.outdated = true
    route.compute_saved!

    if route.geojson_tracks && route.geojson_tracks.any?
      sub_tour_indices = []
      route.geojson_tracks.each do |track_json|
        track = JSON.parse(track_json)
        if track['geometry'] && track['geometry']['polylines'] && track['properties'] && track['properties']['sub_tour_index']
          sub_tour_indices << track['properties']['sub_tour_index']
        end
      end

      assert sub_tour_indices.include?(0), 'Should have polyline with sub_tour_index 0'
      assert sub_tour_indices.include?(1), 'Should have polyline with sub_tour_index 1'
      assert sub_tour_indices.include?(2), 'Should have polyline with sub_tour_index 2'
    end
  end

  test 'should tag adjacent polyline with stop_index for rest without store' do
    route = routes(:route_one_one)
    route.vehicle_usage.update!(store_rest_id: nil)
    rest_stop = route.stops.find { |stop| stop.is_a?(StopRest) }
    assert_not rest_stop.position?

    route.outdated = true
    route.compute_saved!

    tracks = route.geojson_tracks.map { |track_json| JSON.parse(track_json) }
    linestrings = tracks.select { |track| track.dig('geometry', 'polylines').present? }
    assert linestrings.any?, 'Expected geojson tracks after compute'

    trace_for_rest = linestrings.find do |track|
      indices = Array(track.dig('properties', 'stop_indices') || track.dig('properties', 'stop_index'))
      indices.map(&:to_i).include?(rest_stop.index)
    end
    assert trace_for_rest, 'Expected the adjacent leg polyline to carry the rest stop_index'
    assert_equal 1, linestrings.count { |track|
      indices = Array(track.dig('properties', 'stop_indices') || track.dig('properties', 'stop_index'))
      indices.map(&:to_i).include?(rest_stop.index)
    }, 'Rest without store must not create its own polyline leg'

    ratios = trace_for_rest.dig('properties', 'stop_index_ratios') || {}
    ratio = ratios[rest_stop.index.to_s] || ratios[rest_stop.index]
    assert_not_nil ratio, 'Expected a time-based ratio for the unpositioned rest on its leg'
    assert_operator ratio, :>=, 0.0
    assert_operator ratio, :<=, 1.0
  end

  test 'unpositioned rest last without end store is not tagged on a polyline' do
    route = routes(:route_one_one)
    route.vehicle_usage.update!(store_rest_id: nil, store_stop_id: nil)
    route.vehicle_usage.vehicle_usage_set.update!(store_stop_id: nil)
    route = Route.find(route.id)
    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    last_index = route.stops.map(&:index).max
    route.move_stop(rest, last_index)
    route.save!
    route.reload

    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    assert_nil route.vehicle_usage.default_store_stop
    assert_equal route.stops.map(&:index).max, rest.index
    assert_not rest.position?

    route.outdated = true
    route.compute_saved!
    route.route_geojson.reload

    tracks = route.geojson_tracks.map { |track_json| JSON.parse(track_json) }
    linestrings = tracks.select { |track| track.dig('geometry', 'polylines').present? }
    assert linestrings.any?, 'Visits should still produce driving legs'
    tagged = linestrings.any? do |track|
      indices = Array(track.dig('properties', 'stop_indices') || track.dig('properties', 'stop_index'))
      indices.map(&:to_i).include?(rest.index)
    end
    assert_not tagged, 'Rest last without end store has no following leg; map focuses previous stop'
  end

  test 'unpositioned rest first without start store is not tagged on a later polyline' do
    route = routes(:route_one_one)
    route.vehicle_usage.update!(store_rest_id: nil, store_start_id: nil)
    route.vehicle_usage.vehicle_usage_set.update!(store_start_id: nil)
    route = Route.find(route.id)
    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    route.move_stop(rest, 1)
    route.save!
    route.reload

    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    assert_nil route.vehicle_usage.default_store_start
    assert_equal 1, rest.index
    assert_not rest.position?

    route.outdated = true
    route.compute_saved!
    route.route_geojson.reload

    tracks = route.geojson_tracks.map { |track_json| JSON.parse(track_json) }
    linestrings = tracks.select { |track| track.dig('geometry', 'polylines').present? }
    assert linestrings.any?, 'Later visits should still produce driving legs'
    tagged = linestrings.any? do |track|
      indices = Array(track.dig('properties', 'stop_indices') || track.dig('properties', 'stop_index'))
      indices.map(&:to_i).include?(rest.index)
    end
    assert_not tagged, 'Rest first without start store must not reuse a later leg; map focuses next stop'
  end

  test 'unpositioned rest alone without stores produces no rest polyline tag' do
    route = routes(:route_one_one)
    route.vehicle_usage.update!(store_rest_id: nil, store_start_id: nil, store_stop_id: nil)
    route.vehicle_usage.vehicle_usage_set.update!(store_start_id: nil, store_stop_id: nil, store_rest_id: nil)
    StopVisit.where(route_id: route.id).delete_all
    route = Route.find(route.id)

    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    assert_not_nil rest
    assert_equal 1, route.stops.size
    assert_nil route.vehicle_usage.default_store_start
    assert_nil route.vehicle_usage.default_store_stop
    assert_not route.map_marker?(rest), 'Map marker button must be hidden for rest alone without depot'

    route.outdated = true
    route.compute_saved!
    route.route_geojson.reload

    tracks = Array(route.geojson_tracks).map { |track_json| JSON.parse(track_json) }
    linestrings = tracks.select { |track| track.dig('geometry', 'polylines').present? }
    tagged = linestrings.any? do |track|
      indices = Array(track.dig('properties', 'stop_indices') || track.dig('properties', 'stop_index'))
      indices.map(&:to_i).include?(rest.index)
    end
    assert_not tagged, 'Rest alone without stores must not display a rest trace'
    assert_empty linestrings, 'Rest alone without stores must not display any driving leg'
  end

  test 'map_marker? is true when unpositioned rest has another positioned stop' do
    route = routes(:route_one_one)
    route.vehicle_usage.update!(store_rest_id: nil, store_start_id: nil, store_stop_id: nil)
    route.vehicle_usage.vehicle_usage_set.update!(store_start_id: nil, store_stop_id: nil, store_rest_id: nil)
    route = Route.find(route.id)
    rest = route.stops.find { |stop| stop.is_a?(StopRest) }
    visit = route.stops.find { |stop| stop.is_a?(StopVisit) && stop.position? }

    assert route.map_marker?(rest)
    assert route.map_marker?(visit)
  end

  test 'map_marker? is false for unpositioned visit' do
    route = routes(:route_one_one)
    visit_stop = route.stops.find { |stop| stop.is_a?(StopVisit) }
    visit_stop.visit.destination.update_columns(lat: nil, lng: nil)
    visit_stop = Stop.includes(visit: :destination).find(visit_stop.id)

    assert_not visit_stop.position?
    assert_not route.map_marker?(visit_stop)
  end

  test 'available excludes hidden and locked out of route' do
    planning = plannings(:planning_one)
    out_of_route = planning.routes.find { |route| route.vehicle_usage_id.nil? }
    out_of_route.update!(hidden: true, locked: true)

    assert_not_includes planning.routes.available, out_of_route
  end

  test 'available includes out of route when visible' do
    planning = plannings(:planning_one)
    out_of_route = planning.routes.find { |route| route.vehicle_usage_id.nil? }
    out_of_route.update!(hidden: false, locked: false)

    assert_includes planning.routes.available, out_of_route
  end
end
