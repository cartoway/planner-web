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

  test 'should save without loading stops' do
    route = routes(:route_one_one)
    assert route.update(outdated: true)
    assert_not route.stops.loaded?
  end

  test 'should dup' do
    route = routes(:route_one_one)
    route_dup = route.amoeba_dup
    assert_equal route_dup, route_dup.stops[0].route
    route_dup.save!
  end

  test 'should default_stops' do
    route = routes(:route_one_one)
    route.planning.tags.clear
    route.stops.clear
    route.save!
    assert_difference('Stop.count', Visit.joins(:destination).where(destinations: {customer_id: route.planning.customer_id}).count) do
      route.default_stops
      route.save!
    end
  end

  test 'should compute' do
    route = routes(:route_one_one)
    route.distance = route.emission = route.start = route.end = nil
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
    assert_equal 0, route.size_active
    route.active(:all)
    assert_equal 4, route.size_active
    route.stops[0].active = false
    assert_equal 3, route.size_active
    route.active(:foo_bar)
    assert_equal 0, route.size_active

    route.save!
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

  test 'should return the drive time when compute' do
    route = routes(:route_one_one)
    route.compute_saved!
    total_drive_time = route.stops.map(&:drive_time).sum(0) # Total stops drive time
    total_drive_time += route.stop_drive_time # The last stop (in case of store)
    assert_equal total_drive_time, route.drive_time # ensure compute, computed all stops drive time
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
    visits.second.quantities = capacities
    visits.last.quantities = {}

    route.compute_saved({no_geojson: true})
    stops_capacities = route.stops.map(&:out_of_capacity)

    # Second stop is out_of_capacity due to previous set up
    assert_equal true, stops_capacities[1]
    # Last stop must be false, it doesnt deliver "kg" so it's not affected
    assert_equal false, stops_capacities[2]
  end

  test 'should set stops as unmanageable capacity' do
    route = routes(:route_one_one)
    route.vehicle_usage.vehicle.capacities[1] = 0.0
    route.compute_quantities

    route.stops.each { |s|
      if s.is_a?(StopVisit) && s.visit.quantities.key?(1)
        assert !!s.unmanageable_capacity
      end
    }
  end

  test 'should not set stops as unmanageable capacity' do
    route = routes(:route_one_one)
    route.vehicle_usage.vehicle.capacities[1] = nil
    route.compute_quantities

    route.stops.each { |s|
      if s.is_a?(StopVisit) && s.visit.quantities.key?(1)
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
end
