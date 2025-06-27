require 'test_helper'

class StopStoreTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @route = @planning.routes.find{ |route| route.vehicle_usage }
    @store = stores(:store_one)
    @stop_store = StopStore.create!(
      route: @route,
      store: @store,
      index: 1,
      active: true,
      distance: 1.0,
      time: 30.seconds
    )
  end

  test 'should return vehicle usage store duration' do
    @route.vehicle_usage.update! store_duration: 15.minutes.to_i
    @route.vehicle_usage.reload

    assert_equal 15.minutes.to_i, @stop_store.duration
  end

  test 'should return 0 when no store duration is set' do
    @route.vehicle_usage.update! store_duration: nil
    @route.vehicle_usage.reload

    assert_equal 0, @stop_store.duration
  end

  test 'should return vehicle usage set store duration when vehicle usage not set' do
    @route.vehicle_usage.update! store_duration: nil
    @route.vehicle_usage.vehicle_usage_set.update! store_duration: 20.minutes.to_i
    @route.vehicle_usage.reload

    assert_equal 20.minutes.to_i, @stop_store.duration
  end

  test 'should return correct duration time with seconds' do
    @route.vehicle_usage.update! store_duration: 15.minutes.to_i
    @route.vehicle_usage.reload

    expected_time_with_seconds = Time.parse('00:15:00')
    assert_equal expected_time_with_seconds, @stop_store.duration_time_with_seconds
  end

  test 'should return nil duration time with seconds when no duration set' do
    @route.vehicle_usage.update! store_duration: nil
    @route.vehicle_usage.reload

    assert_nil @stop_store.duration_time_with_seconds
  end

  test 'should return 0 for destination duration' do
    assert_equal 0, @stop_store.destination_duration
  end

  test 'should return 0 for destination duration time with seconds' do
    assert_equal 0, @stop_store.destination_duration_time_with_seconds
  end

  test 'should delegate store attributes' do
    assert_equal @store.lat, @stop_store.lat
    assert_equal @store.lng, @stop_store.lng
    assert_equal @store.name, @stop_store.name
    assert_equal @store.street, @stop_store.street
    assert_equal @store.postalcode, @stop_store.postalcode
    assert_equal @store.city, @stop_store.city
  end

  test 'should return store ref' do
    assert_equal @store.ref, @stop_store.ref
  end

  test 'should return position from store' do
    assert_equal @store, @stop_store.position
  end

  test 'should return position? based on store coordinates' do
    assert @stop_store.position?

    @store.update! lat: nil, lng: nil
    assert_not @stop_store.position?
  end

  test 'should return nil for detail and comment' do
    assert_nil @stop_store.detail
    assert_nil @stop_store.comment
  end

  test 'should return nil for phone number' do
    assert_nil @stop_store.phone_number
  end

  test 'should return correct base id' do
    assert_equal "d#{@store.id}", @stop_store.base_id
  end

  test 'should return store updated at for base updated at' do
    assert_equal @store.updated_at, @stop_store.base_updated_at
  end

  test 'should return nil for priority' do
    assert_nil @stop_store.priority
  end

  test 'should return nil for force position' do
    assert_nil @stop_store.force_position
  end

  test 'should return correct string representation' do
    assert_equal "x #{@store.name}", @stop_store.to_s

    @stop_store.update! active: false
    assert_equal "_ #{@store.name}", @stop_store.to_s
  end

  test 'should delegate time window methods to vehicle usage' do
    @route.vehicle_usage.update! time_window_start: 8.hours.to_i, time_window_end: 18.hours.to_i

    assert_equal 8.hours.to_i, @stop_store.time_window_start_1
    assert_equal 18.hours.to_i, @stop_store.time_window_end_1
  end

  test 'should return nil for second time window' do
    assert_nil @stop_store.time_window_start_2
    assert_nil @stop_store.time_window_end_2
    assert_nil @stop_store.time_window_start_2_time
    assert_nil @stop_store.time_window_end_2_time
  end
end
