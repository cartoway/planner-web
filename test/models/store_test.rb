require 'test_helper'

class StoreTest < ActiveSupport::TestCase

  test 'should not save' do
    store = Store.new
    assert_not store.save, 'Saved without required fields'
  end

  test 'should save' do
    customer = customers(:customer_one).stores.build(name: 'plop', city: 'Bordeaux', state: 'Midi-Pyrénées')
    assert customer.save!
    customer.reload
    assert !customer.lat.nil?, 'Latitude not built'
  end

  test 'should destroy' do
    customer = customers(:customer_one)
    assert_difference('customer.stores.size', -1) do
      store = customer.stores.find{ |s| s[:name] == 'store 0' }
      assert store.destroy
      customer.reload
      assert_equal stores(:store_one), vehicle_usages(:vehicle_usage_one_one).store_start
    end
  end

  test 'should destroy in use for vehicle_usage' do
    customer = customers(:customer_one)
    assert_difference('customer.stores.size', -1) do
      store = customer.stores.find{ |s| s[:name] == 'store 1' }
      assert store.destroy
      customer.reload
      assert_not_equal store, vehicle_usages(:vehicle_usage_one_one).store_start
    end
  end

  test 'should not destroy last store' do
    customer = customers(:customer_one)
    assert_not_equal 0, customer.stores.size
    for i in 0..(customer.stores.size - 2)
      assert customer.stores[i].destroy
    end
    customer.reload
    begin
      customer.stores[0].destroy!
      assert false
    rescue
      assert true
    end
  end

  test 'should outdated' do
    store = stores(:store_one)
    assert_not store.customer.plannings.where(name: 'planning1').first.outdated
    store.lat = 10.1
    store.save!
    store.reload
    assert store.customer.plannings.where(name: 'planning1').first.outdated
  end

  test 'should geocode' do
    store = stores(:store_one)
    lat, lng = store.lat, store.lng
    store.geocode
    assert store.lat
    assert_not_equal lat, store.lat
    assert store.lng
    assert_not_equal lng, store.lng
  end

  test 'should geocode with error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      store = stores(:store_one)
      assert store.geocode
      assert 1, store.warnings.size
    end
  end

  test 'should update_geocode' do
    store = stores(:store_one)
    store.city = 'Toulouse'
    store.state = 'Midi-Pyrénées'
    store.lat = store.lng = nil
    lat, lng = store.lat, store.lng
    store.save!
    assert store.lat
    assert_not_equal lat, store.lat
    assert store.lng
    assert_not_equal lng, store.lng
  end

  test 'should update_geocode with error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      store = stores(:store_one)
      store.city = 'Toulouse'
      store.state = 'Midi-Pyrénées'
      store.lat = store.lng = nil
      assert store.save!
      assert 1, store.warnings.size
    end
  end

  test 'should distance' do
    store = stores(:store_one)
    assert_equal 2.51647173560523, store.distance(stores(:store_two))
  end

  test 'should return default color' do
    store = stores :store_one

    assert_equal Planner::Application.config.store_color_default, store.default_color
    assert_equal Planner::Application.config.store_icon_default, store.default_icon
    assert_equal Planner::Application.config.store_icon_size_default, store.default_icon_size

    store.color = '#beef'
    store.icon = 'beef'
    assert_equal store.color, store.default_color
    assert_equal store.icon, store.default_icon
    assert_equal Planner::Application.config.store_icon_size_default, store.default_icon_size
  end

  test 'should have geocoder version' do
    store = stores(:store_one)

    store.geocode
    assert store.geocoder_version
    assert_not_equal nil, store.geocoder_version
  end

  test 'geocoded_at should not be nil' do
    store = stores(:store_one)

    store.geocode
    assert store.geocoded_at
    assert_not_equal nil, store.geocoded_at
  end

  test 'should destroy associated stop_stores when store is destroyed' do
    store = stores(:store_one)
    planning = plannings(:planning_one)
    route = planning.routes.first

    stop_store = StopStore.create!(
      store: store,
      route: route,
      index: route.stops.size
    )

    assert route.stops.include?(stop_store)
    assert_equal store.id, stop_store.store_id

    assert_difference('Stop.count', -1) do
      store.destroy
    end

    assert_nil Stop.find_by(id: stop_store.id)
  end
end
