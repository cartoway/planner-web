require 'test_helper'

class StoreReloadTest < ActiveSupport::TestCase
  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 720, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        yield
      end
    end
  end

  setup do
    @store = stores(:store_one)
    @store_reload = @store.store_reloads.build(ref: 'SR001')
  end

  test 'should not save without store' do
    store_reload = StoreReload.new
    assert_not store_reload.save, 'Saved without required store'
  end

  test 'should save with valid attributes' do
    assert @store_reload.save, 'Failed to save with valid attributes'
  end

  test 'should delegate store attributes' do
    @store_reload.save!
    assert_equal @store.name, @store_reload.name
    assert_equal @store.lat, @store_reload.lat
    assert_equal @store.lng, @store_reload.lng
    assert_equal @store.city, @store_reload.city
    assert_equal @store.customer, @store_reload.customer
  end

  test 'should validate time window end after start' do
    @store_reload.time_window_start = 3600 # 1 hour
    @store_reload.time_window_end = 1800   # 30 minutes
    assert_not @store_reload.valid?, 'Should not be valid with end before start'
    assert_includes @store_reload.errors[:time_window_end], 'doit être après le début du créneau'
  end

  test 'should validate ref uniqueness within store' do
    @store_reload.save!

    duplicate_store_reload = @store.store_reloads.build(ref: 'SR001')
    assert_not duplicate_store_reload.valid?, 'Should not allow duplicate ref within same store'
    assert_includes duplicate_store_reload.errors[:ref], 'est déjà utilisé(e)'
  end

  test 'should allow same ref in different stores' do
    @store_reload.save!

    other_store = stores(:store_two)
    other_store_reload = other_store.store_reloads.build(ref: 'SR001')
    assert other_store_reload.valid?, 'Should allow same ref in different stores'
  end

  test 'should have position from store' do
    @store_reload.save!
    assert @store_reload.position?
    assert_equal @store, @store_reload.position
  end

  test 'should generate base_id' do
    @store_reload.save!
    assert_equal "sr#{@store_reload.id}", @store_reload.base_id
  end

  test 'should return base_updated_at' do
    @store_reload.save!
    expected_time = [@store_reload.updated_at, @store.updated_at].max
    assert_equal expected_time, @store_reload.base_updated_at
  end

  test 'should format to_s with ref' do
    @store_reload.save!
    expected = "#{@store.name} #{@store_reload.ref}"
    assert_equal expected, @store_reload.to_s
  end

  test 'should format to_s without ref' do
    @store_reload.ref = nil
    @store_reload.save!
    assert_equal @store.name, @store_reload.to_s
  end

  test 'should destroy associated stop_stores when destroyed' do
    @store_reload.save!

    # Create a stop_store associated with this store_reload
    route = routes(:route_one_one)
    assert route.add_store_reload(@store_reload)
    route.save!
    route.reload

    assert_difference('StopStore.count', -1) do
      @store_reload.destroy
    end
  end

  test 'should update outdated routes when time windows change' do
    @store_reload.save!

    route = routes(:route_one_one)
    assert route.add_store_reload(@store_reload)
    assert route.outdated

    route.compute
    route.save!

    route.reload
    assert_not route.outdated

    @store_reload.update!(time_window_start: 3600)
    route.reload
    assert route.outdated
  end
end
