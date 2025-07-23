require 'test_helper'

class VehicleUsageTest < ActiveSupport::TestCase

  #  test 'should not save' do
  #    o = vehicle_usage_sets(:vehicle_usage_set_one).vehicle_usages.build()
  #    assert_not o.save, 'Saved without required fields'
  #  end

  test 'should save' do
    vehicle_usage = vehicle_usage_sets(:vehicle_usage_set_one).vehicle_usages.build(vehicle: vehicles(:vehicle_one))
    vehicle_usage.save!
  end

  test 'should change store' do
    store = stores(:store_one).dup
    store.name = 's2'
    store.save!
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.store_start = store
    vehicle_usage.save!
    assert_equal store, vehicle_usage.store_start
    assert_not_equal store, vehicle_usage.store_stop
  end

  test 'should update outdated for store' do
    store = stores(:store_one).dup
    store.save!
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    assert_not vehicle_usage.routes[-1].outdated
    [:store_start, :store_stop, :store_rest].shuffle.each do |attr|
      vehicle_usage[attr.to_s + '_id'] = store.id
      vehicle_usage.save!
      vehicle_usage.reload
      assert vehicle_usage.routes[-1].outdated
    end
  end

  test 'should update outdated if service time or work time changed' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    route = vehicle_usage.routes.take
    assert !route.outdated
    [:service_time_start, :service_time_end, :work_time].shuffle.each do |attr|
      assert vehicle_usage.send(attr).nil?
      vehicle_usage.update! attr => 10.minutes.to_i
      assert route.reload.outdated
    end
  end

  test 'setting a rest duration requires time start and stop' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update! rest_start: nil, rest_stop: nil, rest_duration: nil
    assert vehicle_usage.valid?

    vehicle_usage.vehicle_usage_set.update! rest_start: nil, rest_stop: nil, rest_duration: nil
    vehicle_usage.rest_duration = 15.minutes.to_i
    assert_not vehicle_usage.valid?
    assert_equal [:rest_start, :rest_stop], vehicle_usage.errors.attribute_names

    vehicle_usage.rest_start = 10.hours.to_i
    vehicle_usage.rest_stop = 11.hours.to_i
    assert vehicle_usage.valid?

    vehicle_usage.update! rest_start: nil, rest_stop: nil, rest_duration: nil
    vehicle_usage.rest_stop = 11.hours.to_i
    assert_not vehicle_usage.valid?
    assert_equal [:rest_stop, :rest_duration], vehicle_usage.errors.attribute_names
  end

  test 'should validate rest range in relation to the working time range' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update rest_start: '12:00', rest_stop: '14:00', time_window_start: '08:00', time_window_end: '18:00', service_time_start: '00:30', service_time_end: '00:15'
    assert vehicle_usage.valid?
    vehicle_usage.update rest_start: '07:00', rest_stop: '14:00', time_window_start: '08:00', time_window_end: '18:00', service_time_start: '00:45', service_time_end: '00:30'
    assert_equal [:base], vehicle_usage.errors.attribute_names
  end

  test 'should validate service working day start/end in relation to the working time range' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', service_time_start: '00:30', service_time_end: '00:15'
    assert vehicle_usage.valid?
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', service_time_start: '18:00', service_time_end: '1:00'
    assert_equal [:service_time_start], vehicle_usage.errors.attribute_names
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', service_time_start: '08:00', service_time_end: '18:00'
    assert_equal [:service_time_end], vehicle_usage.errors.attribute_names
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', service_time_start: '08:00', service_time_end: '08:00'
    assert_equal [:base], vehicle_usage.errors.attribute_names
  end

  test 'should validate work time in relation to the working time range and service range' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', work_time: '09:00'
    assert vehicle_usage.valid?
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', work_time: '12:00'
    assert_not vehicle_usage.valid?
    assert_equal [:work_time], vehicle_usage.errors.attribute_names
    vehicle_usage.update time_window_start: '08:00', time_window_end: '18:00', service_time_start: '01:00', service_time_end: '01:00', work_time: '09:00'
    assert_not vehicle_usage.valid?
    assert_equal [:work_time], vehicle_usage.errors.attribute_names
  end

  test 'should validate time_window_start and time_window_end time exceeding one day' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update time_window_start: '08:00', time_window_end: '32:00'
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_end, 32 * 3_600
  end

  test 'should validate time_window_start and time_window_end time from different type' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update time_window_start: '08:00', time_window_end: 32 * 3_600
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_end, 32 * 3_600
    vehicle_usage.update time_window_start: '08:00', time_window_end: '32:00'
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_end, 32 * 3_600
    vehicle_usage.update time_window_start: '08:00', time_window_end: 115200.0
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_end, 32 * 3_600
    vehicle_usage.update time_window_start: Time.parse('08:00'), time_window_end: '32:00'
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_start, 8 * 3_600
    vehicle_usage.update time_window_start: DateTime.parse('2011-01-01 08:00'), time_window_end: '32:00'
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_start, 8 * 3_600
    vehicle_usage.update time_window_start: 8.hours, time_window_end: '32:00'
    assert vehicle_usage.valid?
    assert_equal vehicle_usage.time_window_start, 8 * 3_600
  end

  test 'should have tags' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    assert vehicle_usage.update(tags: [tags(:tag_one), tags(:tag_two)])
    assert_equal vehicle_usage.reload.tags.size, 2
  end

  test 'should not have tags from other customer' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    assert_not vehicle_usage.update(tags: [tags(:tag_three)])
    assert_equal vehicle_usage.reload.tags.size, 0
  end

  test 'should delete vehicle usage and place routes in out of route section' do
    planning = plannings(:planning_one)
    out_of_route = planning.routes.detect{|route| !route.vehicle_usage }
    route = planning.routes.detect{|route| route.ref == 'route_one' }

    vehicle_usage = route.vehicle_usage
    vehicle_usage.destroy

    assert_equal 0, route.stops.reload.select{|stop| stop.is_a?(StopVisit) }.count
    assert_equal 4, out_of_route.stops.reload.select{|stop| stop.is_a?(StopVisit) }.count
  end

  test 'disable vehicle usage' do
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 720, '_ibE_seK_seK_seK'] } } ) do
      planning = plannings(:planning_one)
      out_of_route = planning.routes.detect{|route| !route.vehicle_usage }
      route = planning.routes.detect{|route| route.ref == 'route_one' }
      vehicle_usage = route.vehicle_usage

      # There are 3 Stops on this Route, + 1 Rest Stop
      assert_equal 3, route.stops.reload.select{|stop| stop.is_a?(StopVisit) }.count
      assert_equal 1, route.stops.reload.select{|stop| stop.is_a?(StopRest) }.count
      assert_equal 1, out_of_route.stops.reload.select{|stop| stop.is_a?(StopVisit) }.count

      # Scope includes Vehicle Usage
      assert VehicleUsage.active.find(route.vehicle_usage_id)

      # Deactivating Vehicle Usage
      assert_difference('planning.routes.size', -1) do
        assert vehicle_usage.active
        vehicle_usage.update! active: false
        assert !vehicle_usage.active
        planning.reload
      end

      # Scope does not include Vehicle Usage
      assert_raises ActiveRecord::RecordNotFound do
        VehicleUsage.active.find(route.vehicle_usage_id)
      end

      # All Stops are now out of route
      assert_raises ActiveRecord::RecordNotFound do
        route.reload
      end

      # Activating Vehicle Usage
      assert_difference('planning.routes.size', 1) do
        vehicle_usage.update! active: true
        assert vehicle_usage.active
      end

      # Routes should be recreated
      route = planning.routes.reload.detect{|planning_route| planning_route.vehicle_usage_id == vehicle_usage.id }
      assert route.persisted?
      assert_equal 0, route.stops.reload.select{|stop| stop.is_a?(StopVisit) }.count
      assert_equal 1, route.stops.reload.select{|stop| stop.is_a?(StopRest) }.count
      assert_equal 4, out_of_route.stops.reload.select{|stop| stop.is_a?(StopVisit) }.count
    end
  end

  test 'should destroy disabled vehicle usage' do
    planning = plannings(:planning_one)
    vehicle_usage = planning.vehicle_usage_set.vehicle_usages.first.vehicle
    planning.vehicle_usage_remove(vehicle_usage)

    assert vehicle_usage.destroy
  end

  test 'rest stop should not be after rest start' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)

    assert_raises ActiveRecord::RecordInvalid do
      vehicle_usage.update! rest_stop: '09:00', rest_start: '10:00'
    end
  end

  test 'time_window_start should not be after time_window_end' do
    vehicle_usage = vehicle_usage_sets(:vehicle_usage_set_one)

    assert_raises ActiveRecord::RecordInvalid do
      vehicle_usage.update! time_window_end: '09:00', time_window_start: '10:00'
    end
  end

  setup do
    @vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
  end

  test 'should validate cost_distance as float' do
    @vehicle_usage.cost_distance = 10.5
    assert @vehicle_usage.valid?

    @vehicle_usage.cost_distance = 'not a float'
    assert_not @vehicle_usage.valid?

    @vehicle_usage.cost_distance = nil
    assert @vehicle_usage.valid?
  end

  test 'should validate cost_fixed as float' do
    @vehicle_usage.cost_fixed = 15.75
    assert @vehicle_usage.valid?

    @vehicle_usage.cost_fixed = 'not a float'
    assert_not @vehicle_usage.valid?

    @vehicle_usage.cost_fixed = nil
    assert @vehicle_usage.valid?
  end

  test 'should validate cost_time as float' do
    @vehicle_usage.cost_time = 20.25
    assert @vehicle_usage.valid?

    @vehicle_usage.cost_time = 'not a float'
    assert_not @vehicle_usage.valid?

    @vehicle_usage.cost_time = nil
    assert @vehicle_usage.valid?
  end

  test 'should accept integer values for costs' do
    @vehicle_usage.cost_distance = 10
    @vehicle_usage.cost_fixed = 15
    @vehicle_usage.cost_time = 20
    assert @vehicle_usage.valid?
  end

  test 'should accept zero values for costs' do
    @vehicle_usage.cost_distance = 0
    @vehicle_usage.cost_fixed = 0
    @vehicle_usage.cost_time = 0
    assert @vehicle_usage.valid?
  end

  test 'should reject negative values for costs' do
    @vehicle_usage.cost_distance = -10.5
    @vehicle_usage.cost_fixed = -15.75
    @vehicle_usage.cost_time = -20.25
    assert_not @vehicle_usage.valid?
  end

  test 'should update outdated if store duration changed' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    route = vehicle_usage.routes.take
    assert !route.outdated

    vehicle_usage.update! store_duration: 10.minutes.to_i
    assert route.reload.outdated
  end

  test 'should use vehicle usage store duration when set' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update! store_duration: 15.minutes.to_i
    vehicle_usage.vehicle_usage_set.update! store_duration: 30.minutes.to_i

    assert_equal 15.minutes.to_i, vehicle_usage.default_store_duration
  end

  test 'should fallback to vehicle usage set store duration when vehicle usage not set' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update! store_duration: nil
    vehicle_usage.vehicle_usage_set.update! store_duration: 30.minutes.to_i

    assert_equal 30.minutes.to_i, vehicle_usage.default_store_duration
  end

  test 'should return 0 when no store duration is set' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update! store_duration: nil
    vehicle_usage.vehicle_usage_set.update! store_duration: nil

    assert_equal 0, vehicle_usage.default_store_duration
  end

  test 'should return correct store duration time' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update! store_duration: 15.minutes.to_i

    expected_time = Time.parse('00:15')
    assert_equal expected_time, vehicle_usage.default_store_duration_time
  end

  test 'should return correct store duration time with seconds' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.update! store_duration: 15.minutes.to_i

    expected_time_with_seconds = Time.parse('00:15:00')
    assert_equal expected_time_with_seconds, vehicle_usage.default_store_duration_time_with_seconds
  end
end
