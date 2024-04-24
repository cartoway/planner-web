require 'test_helper'
require 'routers/router_wrapper'

class D < Struct.new(:lat, :lng, :id, :time_window_start_1, :time_window_end_1, :time_window_start_2, :time_window_end_2, :priority, :duration, :vehicle_usage, :quantities, :quantities_operations, :tags)
  def visit
    # self
    destination = Struct.new(:tags).new([])
    Struct.new(:destination, :tags).new(destination, tags || [])
  end
  def default_quantities?
    false
  end
  def route
    Struct.new(:vehicle_usage, :vehicle_usage_id).new(vehicle_usage, vehicle_usage.try(&:id))
  end
end

class PlanningTest < ActiveSupport::TestCase

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        yield
      end
    end
  end

  # default order, rest at the end
  def optimizer_route(positions, services, vehicles)
    [[]] + [(services + vehicles[0][:rests]).collect{ |s| s[:stop_id] }]
  end

  # return all services in reverse order in first route, rests at the end
  def optimizer_global(positions, services, vehicles)
    [[]] + vehicles.each_with_index.map{ |v, i|
      ((i.zero? ? services.reject{ |s| s[:vehicle_usage_id] } : []) + services.select{ |s| s[:vehicle_usage_id] && s[:vehicle_usage_id] == v[:id] } + v[:rests]).map{ |s|
        s[:stop_id]
      }.reverse
    }
  end

  test 'should not save' do
    planning = Planning.new
    assert_not planning.save, 'Saved without required fields'
  end

  test 'should not save with inconsistent attributes' do
    {
      vehicle_usage_set: vehicle_usage_sets(:vehicle_usage_set_two),
      zonings: [zonings(:zoning_three)]
    }.each{ |k, v|
      attr = {name: 'plop'}
      attr[k] = v
      planning = customers(:customer_one).plannings.build(attr)
      assert_not planning.save, 'Saved with inconsistent attributes'
    }
  end

  test 'should save' do
    planning = customers(:customer_one).plannings.build(name: 'plop', vehicle_usage_set: vehicle_usage_sets(:vehicle_usage_set_one), zonings: [zonings(:zoning_one)])
    planning.default_routes
    planning.save!
  end

  test 'should save according to tag operation' do
    planning_and_tags = customers(:customer_two).plannings.build(name: 'plop', vehicle_usage_set: vehicle_usage_sets(:vehicle_usage_set_two), zonings: [zonings(:zoning_three)], tag_operation: '_and', tag_ids: [tags(:tag_three).id, tags(:tag_four).id])
    planning_and_tags.default_routes
    planning_and_tags.save!
    assert_equal 1, planning_and_tags.visits_compatibles.count

    planning_or_tags = customers(:customer_two).plannings.build(name: 'plop 2', vehicle_usage_set: vehicle_usage_sets(:vehicle_usage_set_two), zonings: [zonings(:zoning_three)], tag_operation: '_or', tag_ids: [tags(:tag_three).id, tags(:tag_four).id])
    planning_or_tags.default_routes
    planning_or_tags.save!
    assert_equal 2, planning_or_tags.visits_compatibles.count
  end

  test 'should not loading stops after save import' do
    # Without zonings
    planning = customers(:customer_one).plannings.build(name: 'plop', vehicle_usage_set: vehicle_usage_sets(:vehicle_usage_set_one))
    planning.default_routes
    planning.compute
    Planning.import([planning], recursive: true, validate: false)

    without_loading Stop do
      t, z = planning.tags, planning.zonings
      planning.reload
      planning.tags, planning.zonings = t, z
      planning.routes.each { |route| route.complete_geojson }
      planning.save!
    end
  end

  test 'should dup' do
    planning = plannings(:planning_one)
    planning_dup = planning.duplicate

    assert_equal planning_dup, planning_dup.routes[0].planning
    planning_dup.save!
    planning_dup.routes.each{ |r|
      assert_not r.outdated
    }
  end

  test 'should set_routes' do
    planning = plannings(:planning_one)

    planning.set_routes({'abc' => {visits: [[visits(:visit_one)]]}})
    assert planning.routes[1].stops.select{ |stop| stop.is_a?(StopVisit) }.collect(&:visit).include?(visits(:visit_one))
    planning.save!
  end

  test 'should not set_routes for tags' do
    planning = plannings(:planning_one)
    planning.tags << tags(:tag_two)

    planning.set_routes({'abc' => {visits: [[visits(:visit_one)]]}})
    assert_not planning.routes[1].stops.select{ |stop| stop.is_a?(StopVisit) }.collect(&:visit).include?(visits(:visit_one))
    planning.save!
  end

  test 'should set_routes with ref_vehicle' do
    planning = plannings(:planning_one)

    planning.set_routes({'abc' => {visits: [[visits(:visit_one)]], ref_vehicle: vehicles(:vehicle_three).ref}})
    assert planning.routes.find{ |r| r.vehicle_usage.try(&:vehicle) == vehicles(:vehicle_three) }.stops.select{ |stop| stop.is_a?(StopVisit) }.collect(&:visit).include?(visits(:visit_one))
    planning.save!
  end

  test 'should not set_routes for size' do
    planning = plannings(:planning_one)

    assert !planning.set_routes(Hash[0.upto(planning.routes.size).collect{ |i| ["route#{i}", {visits: [visits(:visit_one)]}] }])
  end

  test 'should vehicle_usage_add' do
    planning = plannings(:planning_one)
    assert_difference('Stop.count', 1) do # One StopRest
      assert_difference('Route.count', 1) do
        planning.vehicle_usage_add(vehicle_usages(:vehicle_usage_one_three))
        planning.save!
      end
    end
  end

  test 'should vehicle_usage_remove' do
    planning = plannings(:planning_one)
    assert_difference('Stop.count', -1) do
      assert_difference('Route.count', -1) do
        planning.vehicle_usage_remove(vehicle_usages(:vehicle_usage_one_one))
        planning.save!
      end
    end
  end

  test 'should visit_add' do
    planning = plannings(:planning_one)
    assert_difference('Stop.count') do
      planning.visit_add(visits(:visit_two))
      planning.save!
    end
  end

  test 'should visit_remove' do
    planning = plannings(:planning_one)
    assert_difference('Stop.count', -2) do
      planning.visit_remove(visits(:visit_one))
      planning.save!
    end
  end

  test 'move stop on same route from inside to start' do
    planning = plannings(:planning_one)
    r = planning.routes.select{ |route| route == routes(:route_one_one) }.first
    s = r.stops[1]
    assert_equal 2, s.index
    assert_difference('Stop.count', 0) do
      planning.move_stop(r, s, 1)
      planning.save!
      s.reload
      assert_equal 1, s.index
    end
  end

  test 'move stop on same route from inside to end' do
    planning = plannings(:planning_one)
    r = planning.routes.select{ |route| route == routes(:route_one_one) }.first
    s = r.stops[1]
    assert_equal 2, s.index
    assert_difference('Stop.count', 0) do
      planning.move_stop(r, s, 3)
      planning.save!
      s.reload
      assert_equal 3, s.index
    end
  end

  test 'move stop on same route from start to inside' do
    planning = plannings(:planning_one)
    r = planning.routes.select{ |route| route == routes(:route_one_one) }.first
    s = r.stops[0]
    assert_equal 1, s.index
    assert_difference('Stop.count', 0) do
      planning.move_stop(r, s, 2)
      planning.save!
      s.reload
      assert_equal 2, s.index
    end
  end

  test 'move stop on same route from end to inside' do
    o = plannings(:planning_one)
    r = o.routes.select{ |route| route == routes(:route_one_one) }.first
    s = r.stops[2]
    assert_equal 3,  s.index
    assert_difference('Stop.count', 0) do
      o.move_stop(r, s, 2)
      o.save!
      s.reload
      assert_equal 2, s.index
    end
  end

  test 'move stop from unaffected to affected route' do
    o = plannings(:planning_one)
    s = o.routes.select{ |route| route == routes(:route_zero_one) }.first.stops[0]
    assert s.index
    r = o.routes.select{ |route| route == routes(:route_one_one) }.first
    assert_difference('Stop.count', 0) do
      assert_difference('r.stops.size', 1) do
        o.move_stop(r, s, 1)
        o.save!
      end
    end
  end

  test 'move stop from unaffected to affected route with automatic_insert' do
    o = plannings(:planning_one)
    s = o.routes.select{ |route| route == routes(:route_zero_one) }.first.stops[0]
    assert s.index
    r = o.routes.select{ |route| route == routes(:route_one_one) }.first
    assert_difference('Stop.count', 0) do
      assert_difference('r.stops.size', 1) do
        o.move_stop(r, s, nil)
        o.save!
      end
    end
  end

  test 'move stop from affected to affected route' do
    o = plannings(:planning_one)
    s = o.routes.select{ |route| route == routes(:route_one_one) }.first.stops[0]
    assert s.index
    r = o.routes.select{ |route| route == routes(:route_three_one) }.first
    assert_difference('Stop.count', 0) do
      assert_difference('r.stops.size', 1) do
        o.move_stop(r, s, 1)
        o.save!
      end
    end
  end

  test 'move stop to unaffected route' do
    o = plannings(:planning_one)
    s = o.routes.select{ |route| route == routes(:route_one_one) }.first.stops[1]
    assert s.index
    r = o.routes.select{ |route| route == routes(:route_zero_one) }.first
    assert_difference('Stop.count', 0) do
      assert_difference('r.stops.size', 1) do
        o.move_stop(r, s, 1)
        o.save!
      end
    end
  end

  test 'should compute' do
    o = plannings(:planning_one)
    assert_no_difference('Stop.count') do
      o.compute
      o.routes.select{ |r| r.vehicle_usage }.each{ |r|
        assert_not r.outdated
      }
      o.save!
    end
  end

  test 'should compute with non geocoded' do
    o = plannings(:planning_one)
    d0 = o.routes[0].stops[0].visit.destination
    d0.lat = d0.lng = nil
    o.compute
    o.routes.select{ |r| r.vehicle_usage }.each{ |r|
      assert_not r.outdated
    }
  end

  test 'should outdated' do
    o = plannings(:planning_one)
    assert_not o.outdated

    o.routes[1].outdated = true
    assert o.outdated
  end

  test 'should update zoning' do
    o = plannings(:planning_one)
    assert_not o.zoning_outdated
    o.zonings = [zonings(:zoning_two)]
    o.save!
    assert_not o.outdated
  end

  test 'should split by zone' do
    o = plannings(:planning_one)
    o.zoning_outdated = true
    r = o.routes.find{ |r| !r.vehicle_usage }
    assert_difference('r.stops.size', 2) do
      o.split_by_zones(nil)
      assert_not o.zoning_outdated
      assert_equal 1, o.routes.select{ |route| route == routes(:route_three_one) }.first.stops.size
    end
  end

  test 'should automatic insert' do
    planning = plannings(:planning_one)
    stops_count = planning.routes.collect{ |r| r.stops.size }.inject(:+)
    planning.zonings = []
    assert_difference('Stop.count', 0) do
      # route_zero has not any vehicle_usage => stop will be affected to another route
      planning.automatic_insert(planning.routes.find{ |r| !r.vehicle_usage }.stops[0])
      planning.save!
    end
    planning.reload
    assert_equal 3, planning.routes.size
    assert_equal 0, planning.routes.find{ |r| !r.vehicle_usage }.stops.size
    assert_equal stops_count, planning.routes.select{ |r| r.vehicle_usage }.collect{ |r| r.stops.size }.inject(:+)
  end

  test 'should return a candidate route' do
    planning = plannings(:planning_one)
    destination = destinations(:destination_one)
    planning.zonings = []
    assert_difference('Stop.count', 0) do
      data = planning.candidate_insert(destination)
      assert_kind_of Hash, data
      assert_kind_of Route, data[:route]
      assert_kind_of Integer, data[:index]
      assert_kind_of Integer, data[:time]
      assert_kind_of Float, data[:distance]
    end
  end

  test 'should apply orders' do
    o = plannings(:planning_one)
    r = o.routes.find{ |ro| ro.ref == 'route_one' }
    assert r.stops[0].active
    assert r.stops[1].active

    oa = order_arrays(:order_array_one)
    o.apply_orders(oa, 0)
    assert r.stops[0].active
    assert_not r.stops[1].active
    o.save!
  end

  test 'should apply orders and destroy' do
    o = plannings(:planning_one)
    oa = order_arrays(:order_array_one)
    o.apply_orders(oa, 0)
    o.save!
    oa.destroy
    o.save!
  end

  test 'plan with service time' do
    v = vehicle_usages(:vehicle_usage_one_one)
    r = v.routes.take

    # 1st computation, set Stop times
    r.outdated = true
    r.compute
    stop_times = r.stops.map &:time
    route_start = r.start
    route_end = r.end

    # Add Service Time
    v.vehicle_usage_set.update!(
      service_time_start: 10.minutes.to_i,
      service_time_end: 25.minutes.to_i
    )

    # 2nd computation
    r.outdated = true
    r.compute
    stop_times2 = r.stops.map &:time
    route_start2 = r.start
    route_end2 = r.end

    # Make sure time has been added to route start and end, and stops are still in tw
    assert_equal route_start - 10.minutes.to_i, route_start2
    assert_equal stop_times[0], stop_times2[0]
    assert_equal route_end + 25.minutes.to_i, route_end2

    # Vehicle Usage overrides Service Time values
    v.update!(
      service_time_start: 50.minutes.to_i,
      service_time_end: 20.minutes.to_i
    )

    # 3rd computation
    r.outdated = true
    r.compute
    stop_times3 = r.stops.map &:time
    route_start3 = r.start
    route_end3 = r.end

    # Let's verify route start is minimal, stops are not at same time
    assert_equal Time.parse('10:00:00').seconds_since_midnight.to_i, route_start3
    assert_not_equal stop_times[0], stop_times3[0]
    assert_equal route_end + 20.minutes.to_i, route_end3

    # First stop should not be out of time window
    assert !r.stops[0].out_of_window

    # Change time window
    r.stops[0].visit.update!(
      time_window_start_1: v.service_time_start + 5.minutes.to_i,
      time_window_end_1: v.service_time_start + 10.minutes.to_i
    )

    # Compute a last time, this stop should be out of time window
    r.outdated = true
    r.compute
    assert r.stops[0].out_of_window
  end

  test 'plan using stores without lat or lng' do
    v = vehicle_usages(:vehicle_usage_one_one)
    r = v.routes.take
    r.planning.customer.stores.update_all lat: nil, lng: nil
    r.outdated = true
    r.compute
    r.stops.sort_by(&:index).each_with_index do |stop, index|
      if index.zero?
        # Can't trace path, store has no lat / lng to start with
        assert_equal 0, stop.distance
        assert_equal Time.parse('10:44:25').seconds_since_midnight.to_i, stop.time
      elsif index == r.stops.length - 1
        assert stop.distance.nil?
      else
        assert_equal 1.0, stop.distance
      end
    end
  end

  test 'validates format of REF field with invalid characters' do
    planning = plannings :planning_one
    assert_raises(ActiveRecord::RecordInvalid) do
      planning.update! ref: "test.abcd"
    end

    assert_equal ["ne doit pas contenir les caractères \".\", \"\\\" ou \"/\""], planning.errors[:ref]
  end

  test 'validates format of REF field with valid characters' do
    planning = plannings :planning_one
    assert planning.update! ref: "testabcd!@\#{$%^&*()_+},;'\"`[]|{}:<>?-=~"
  end

  test 'validates format of REF field with spaces' do
    planning = plannings :planning_one
    assert planning.update! ref: "  test abcd   "
    assert_equal "test abcd", planning.ref
  end

  test 'date format' do
    orig_locale = I18n.locale
    begin
      planning = plannings :planning_one
      planning.update! date: Date.new(2017, 1, 31)
      I18n.locale = :en
      assert_equal '01-31-2017', I18n.l(planning.date.to_time, format: :datepicker)
      I18n.locale = :fr
      assert_equal '31-01-2017', I18n.l(planning.date.to_time, format: :datepicker)
    ensure
      I18n.locale = orig_locale
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      planning.update!(date: '20-12-0031')
    end
  end

  test 'duplicate should not change zonings outdated flag when initially false' do
    planning = plannings :planning_one
    assert !planning.zoning_outdated
    dup_planning = planning.duplicate
    dup_planning.save!
    assert !dup_planning.zoning_outdated
  end

  test 'duplicate should not change zonings outdated flag when initially true' do
    planning = plannings :planning_one
    planning.update! zoning_outdated: true
    assert planning.zoning_outdated
    dup_planning = planning.duplicate
    dup_planning.save!
    assert dup_planning.zoning_outdated
  end

  test 'should no amalgamate point at same position' do
    route = routes(:route_one_one)

    initial_positions = [D.new(1,1,1), D.new(2,2,2), D.new(3,3,3)]
    ret = route.planning.send(:amalgamate_stops_same_position, initial_positions, false, [route.vehicle_usage]) { |positions|
      assert_equal 3, positions.size
      pos = positions.sort
      [pos.collect{ |p|
        p[2]
      }]
    }
    assert_equal initial_positions.size, ret[0].size
    assert_equal 1.upto(initial_positions.size).to_a, ret[0]
  end

  test 'should amalgamate point at same position' do
    route = routes(:route_one_one)

    initial_positions = [D.new(1,1,1,nil,nil,nil,nil,nil,0,nil,nil, nil,[Struct.new(:label).new('skills')]), D.new(2,2,2,nil,nil,nil,nil,nil,0), D.new(2,2,3,nil,nil,nil,nil,nil,0), D.new(3,3,4,nil,nil,nil,nil,nil,0)]
    ret = route.planning.send(:amalgamate_stops_same_position, initial_positions, false, [route.vehicle_usage]) { |positions|
      assert_equal 3, positions.size
      pos = positions.sort
      [pos.collect{ |p|
        p[2]
      }]
    }
    assert_equal initial_positions.size, ret[0].size
    assert_equal 1.upto(initial_positions.size).to_a, ret[0]
    assert_equal initial_positions.first.tags.size, 1
  end

  test 'should no amalgamate point at same position, tw' do
    route = routes(:route_one_one)

    positions = [D.new(1,1,1,nil,nil,nil,nil,nil,0), D.new(2,2,2,nil,nil,nil,nil,nil,0), D.new(2,2,3,10,20,nil,nil,nil,0), D.new(3,3,4,nil,nil,nil,nil,nil,0)]
    ret = route.planning.send(:amalgamate_stops_same_position, positions, false, [route.vehicle_usage]) { |positions|
      assert_equal 4, positions.size
      [(1..(positions.size)).to_a]
    }
    assert_equal positions.size, ret[0].size
    assert_equal 1.upto(positions.size).to_a, ret[0]
  end

  test 'should optimize one route with one store rest' do
    route = routes(:route_one_one)
    optim = route.planning.optimize([route], { global: false }) { |*a|
      optimizer_route(*a)
    }
    assert_equal [route.stops.collect(&:id)], optim
  end

  test 'should optimize one route with one no-geoloc rest' do
    route = routes(:route_one_one)
    vehicle_usages(:vehicle_usage_one_one).update! store_rest: nil
    vehicle_usage_sets(:vehicle_usage_set_one).update! store_rest: nil
    route.reload
    optim = route.planning.optimize([route], { global: false }) { |*a|
      optimizer_route(*a)
    }
    assert_equal [route.stops.collect(&:id)], optim
  end

  test 'should optimize one route without any store' do
    route = routes(:route_one_one)
    vehicle_usages(:vehicle_usage_one_one).update! store_start: nil, store_stop: nil, store_rest: nil
    vehicle_usage_sets(:vehicle_usage_set_one).update! store_start: nil, store_stop: nil, store_rest: nil
    route.reload
    optim = route.planning.optimize([route], { global: false }) { |*a|
      optimizer_route(*a)
    }
    assert_equal [route.stops.collect(&:id)], optim
  end

  test 'should optimize one route with none geoloc store' do
    route = routes(:route_three_one)
    optim = route.planning.optimize([route], { global: false }) { |*a|
      optimizer_route(*a)
    }
    assert_equal [route.stops.collect(&:id)], optim
  end

  test 'should optimize global planning' do
    planning = plannings(:planning_one)
    optim = planning.optimize(planning.routes, { global: true }) { |*a|
      optimizer_global(*a)
    }
    assert_equal 0, optim[0].size
    assert_equal planning.routes[2].stops.select{ |s| s.is_a? StopRest }.size, optim[2].size
    assert_equal planning.routes.map{ |r| r.stops.size }.reduce(&:+), optim.flatten.size
  end

  test 'should optimize planning and reduce matrix depending configuration' do
    # stop lat and lng should be the same
    customers(:customer_one).destinations.each{ |dest| dest.update!(lat: 44.82641, lng: -0.55674) }
    # Visits must have no open and close
    customers(:customer_one).destinations.map{ |d| d.visits.each{ |v| v.update!(time_window_start_1: nil, time_window_end_1: nil, time_window_start_2: nil, time_window_end_2: nil) } }
    # Create a new VehicleUsageSet
    vus = VehicleUsageSet.create(customer_id: customers(:customer_one).id, name: 'VUS test')
    # Create planning
    planning = Planning.create(customer: customers(:customer_one), vehicle_usage_set: vus, name: 'Planning test')
    planning.default_routes
    planning.save

    stops = planning.routes.flat_map(&:stops)
    # should be [nil]
    assert_equal [nil], stops.collect{ |s| s.route.vehicle_usage_id }.uniq
    # should be nil
    assert_nil stops.find{ |stop| stop.is_a?(StopRest) || stop.time_window_start_1 || stop.time_window_end_1 || stop.time_window_start_2 || stop.time_window_end_2 }

    planning.optimize(planning.routes, { global: false }) do |positions, services, vehicles|
      assert_equal stops.count, services.count
      optimizer_global(positions, services, vehicles)
    end
  end

  test 'shoud set late_multiplier to nil when stop is a geolocalized rest during optimization' do
    planning = plannings(:planning_one)
    uri_template = Addressable::Template.new("#{Mapotempo::Application.config.optimizer.url}/vrp/submit.json")
    stub_request(:any, uri_template)
      .with(body: /"late_multiplier":null/)
      .to_return(File.new(File.expand_path('../../web_mocks/', __FILE__) + '/optimizer/optimize.json').read)

    assert_equal ['Pause', 'store 1'], # It should have a Pause (geolocalized rest)
      planning.routes.collect{ |r| r.stops.map{ |s| s.name if s.type == 'StopRest' } }.map(&:compact).flatten

    planning.optimize(planning.routes, { global: false }) do |positions, services, vehicles|
      assert services.collect{ |s| s.key? :rest }.uniq.first # All Service should have a rest key
      # Given parameters in OptimizerWrapper::optimize should contain late_multiplier:null
      optimizer_global(positions, services, vehicles)
    end
  end

  test "shoud transfer vehicle's max_distance (distance) during optimization" do
    planning = plannings(:planning_one)
    uri_template = Addressable::Template.new("#{Mapotempo::Application.config.optimizer.url}/vrp/submit.json")
    stub_request(:any, uri_template)
      .with(body: /distance/)
      .to_return(File.new(File.expand_path('../../web_mocks/', __FILE__) + '/optimizer/optimize.json').read)

    planning.optimize(planning.routes, { global: false }) do |positions, services, vehicles|
      assert vehicles.collect{ |s| s.key? :max_distance }.uniq.first # All Vehicles should have a max_distance key
      # Given parameters in OptimizerWrapper::optimize should contain distance
      optimizer_global(positions, services, vehicles)
    end
  end

  test 'should return all or only active stops after optimization' do
    planning = plannings(:planning_one)
    inactive_stop = planning.routes.third.stops.second
    inactive_stop.update_attribute(:active, false)

    active_optim = planning.optimize(planning.routes, { global: false, active_only: false }) { |*a|
      optimizer_global(*a)
    }
    planning.set_stops(planning.routes, active_optim)
    active_stops = planning.routes.third.stops.map(&:id)

    all_optim = planning.optimize(planning.routes, { global: false, active_only: true }) { |*a|
      optimizer_global(*a)
    }
    planning.set_stops(planning.routes, all_optim, { global: false, active_only: true })
    active_only = planning.routes.third.stops.map(&:id)

    assert_equal active_stops.size, active_only.size
    assert_not_equal active_stops, active_only
  end

  test 'should set stops from unaffected route to active after optimization' do
    planning = plannings(:planning_one)
    initial_inactive_stop = planning.routes.first.stops.first
    initial_inactive_stop.update_attribute(:active, false)

    active_optim = planning.optimize(planning.routes, { global: false, active_only: false }) { |*a|
      optimizer_global(*a)
    }
    planning.set_stops(planning.routes, active_optim)

    assert initial_inactive_stop.reload.active
  end

  test 'should set stops for one route' do
    route = routes(:route_one_one)
    original_order = route.stops.map(&:id)
    route.planning.set_stops([route], [original_order.reverse])
    assert_equal original_order.reverse, route.stops.map(&:id)
    route.planning.save!
    route.reload
    assert_equal original_order.reverse, route.stops.map(&:id)
  end

  test 'should set stops for planning' do
    planning = plannings(:planning_one)
    optim = planning.optimize(planning.routes, { global: true }) { |*a|
      optimizer_global(*a)
    }
    planning.set_stops(planning.routes, optim)
    assert_equal optim, planning.routes.map{ |r| r.stops.map(&:id) }
    planning.save!
    planning.reload
    assert_equal optim, planning.routes.map{ |r| r.stops.map(&:id) }
  end

  test 'should destroy optimizer_job on planning destroy' do
    planning = plannings(:planning_one)
    customer = planning.customer
    job_optimizer = delayed_jobs(:job_optimizer)
    job_optimizer.update(handler: "planning_id:#{planning.id}")
    planning_id = planning.id

    assert Job.on_planning(planning.customer.job_optimizer, planning_id)
    planning.destroy
    customer.reload
    refute Job.on_planning(planning.customer.job_optimizer, planning_id)
  end

  test 'should set stops with a geoloc rest in unassigned' do
    planning = plannings(:planning_one)
    unassigned = planning.routes.flat_map{ |r| r.stops.map(&:id) }
    planning.set_stops(planning.routes, [unassigned] + [[]] * (planning.routes.size - 1))
    assert planning.routes.flat_map{ |r| r.stops.select{ |s| s.is_a? StopRest }.map{ |s| s.route.vehicle_usage.id } }.size == planning.vehicle_usage_set.vehicle_usages.map(&:default_rest_duration?).size
    planning.save!
    planning.reload
    assert planning.routes.flat_map{ |r| r.stops.select{ |s| s.is_a? StopRest }.map{ |s| s.route.vehicle_usage.id } }.size == planning.vehicle_usage_set.vehicle_usages.map(&:default_rest_duration?).size
  end

  test 'should set stops with an unreachable stop' do
    planning = plannings(:planning_one)
    unaffected = stops(:stop_unaffected)
    unaffected.visit.destination.update(lat: -33.137551, lng: 25.3125)
    planning.reload

    ordered_stops = planning.routes.each { |route|
      ids = route.stops.map { |stop| stop.index }
      next if ids.count == 1
      route_ids_valid = true

      # No duplication & Array is consecutive
      ids.each_with_index do |id, i|
        assert_equal id.abs, (i + 1)
        value = id.abs - 1

        if (ids[value] < 0)
          route_ids_valid = false
          break
        else
          ids[value] = -ids[value]
        end
      end

      assert route_ids_valid
    }
  end

  test 'should not set zoning_outdated to true on planning creation' do
    customer = customers(:customer_one)
    customer.max_plannings = customer.plannings.count + 1

    params = {
       name:              'Planning_Zonning',
       zoning_ids:        [customer.zonings.first.id],
       vehicle_usage_set: customer.vehicle_usage_sets.first
    }

    planning = customer.plannings.build(params)
    planning.default_routes

    assert planning.compute && planning.save_import
    assert_not planning.zoning_outdated
  end
end

class PlanningTestError < ActiveSupport::TestCase

  test 'should not compute because of router error' do
    o = plannings(:planning_one)
    Routers::RouterWrapper.stub_any_instance(:compute_batch, []) do
      assert_no_difference('Stop.count') do
        o.split_by_zones(nil)
        o.compute
        o.save!
      end
    end
  end
end
