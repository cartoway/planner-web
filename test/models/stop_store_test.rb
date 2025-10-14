require 'test_helper'

class StopStoreTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @route = @planning.routes.find{ |route| route.vehicle_usage }
    @store = stores(:store_one)
    @store_reload = @store.store_reloads.create!(ref: 'SR001')
    @stop_store = StopStore.create!(
      route: @route,
      store_reload: @store_reload,
      index: 1,
      active: true,
      distance: 1.0,
      time: 30.seconds
    )
  end

  test 'should return 0 for destination duration' do
    assert_equal 0, @stop_store.destination_duration
  end

  test 'should return 0 for destination duration time with seconds' do
    assert_equal 0, @stop_store.destination_duration_time_with_seconds
  end

  test 'should delegate store attributes through store_reload' do
    assert_equal @store.lat, @stop_store.lat
    assert_equal @store.lng, @stop_store.lng
    assert_equal @store.name, @stop_store.name
    assert_equal @store.street, @stop_store.street
    assert_equal @store.postalcode, @stop_store.postalcode
    assert_equal @store.city, @stop_store.city
  end

  test 'should return store_reload ref or store ref' do
    assert_equal @store_reload.ref, @stop_store.ref

    @store_reload.update!(ref: nil)
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

  test 'should return correct base id with store_reload' do
    assert_equal "sr#{@store_reload.id}", @stop_store.base_id
  end

  test 'should return max of store_reload and store updated at for base updated at' do
    expected_time = [@store_reload.updated_at, @store.updated_at].max
    assert_equal expected_time, @stop_store.base_updated_at
  end

  test 'should return nil for priority' do
    assert_nil @stop_store.priority
  end

  test 'should return nil for force position' do
    assert_nil @stop_store.force_position
  end

  test 'should return correct string representation with store_reload ref' do
    assert_equal "x #{@store.name} #{@store_reload.ref}", @stop_store.to_s

    @stop_store.update! active: false
    assert_equal "_ #{@store.name} #{@store_reload.ref}", @stop_store.to_s
  end

  test 'should return correct string representation without store_reload ref' do
    @store_reload.update!(ref: nil)
    assert_equal "x #{@store.name}", @stop_store.to_s
  end

  test 'should delegate time window methods to store_reload' do
    @store_reload.update!(
      time_window_start: 8.hours.to_i,
      time_window_end: 18.hours.to_i
    )

    assert_equal 8.hours.to_i, @stop_store.time_window_start
    assert_equal 18.hours.to_i, @stop_store.time_window_end
  end

  test 'should allow creating stop_stores up to max_reload per route' do
    @route.vehicle_usage.update!(max_reload: 2)
    @route.reload

    # already one created in setup
    second = StopStore.new(route: @route, store_reload: @store_reload, index: 2, active: true)
    assert second.valid?, second.errors.full_messages.join(", ")
    assert second.save!, 'Second StopStore should be saved when within max_reload'

    third = StopStore.create(route: @route, store_reload: @store_reload, index: 3, active: true)
    refute third.save
    assert_includes third.errors[:base], I18n.t('activerecord.errors.models.stop_store.max_reload_exceeded', default: 'Maximum number of reloads exceeded for this route')
  end
end
