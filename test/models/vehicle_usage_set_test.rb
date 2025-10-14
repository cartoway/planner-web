require 'test_helper'

class VehicleUsageSetTest < ActiveSupport::TestCase
  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  setup do
    @vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
  end

  test 'should not save' do
    vehicle_usage_set = customers(:customer_one).vehicle_usage_sets.build
    assert_not vehicle_usage_set.save, 'Saved without required fields'
  end

  test 'should save' do
    vehicle_usage_set = customers(:customer_one).vehicle_usage_sets.build(name: '1', max_distance: 200000)
    vehicle_usage_set.save!
  end

  test 'should validate time_window_start and time_window_end time exceeding one day' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: '32:00'
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_end, 32 * 3_600
  end

  test 'should validate time_window_start and time_window_end time from different type' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: 32 * 3_600
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_end, 32 * 3_600
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: '32:00'
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_end, 32 * 3_600
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: 115200.0
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_end, 32 * 3_600
    vehicle_usage_set.update time_window_start: Time.parse('08:00'), time_window_end: '32:00'
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_start, 8 * 3_600
    vehicle_usage_set.update time_window_start: DateTime.parse('2011-01-01 08:00'), time_window_end: '32:00'
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_start, 8 * 3_600
    vehicle_usage_set.update time_window_start: 8.hours, time_window_end: '32:00'
    assert vehicle_usage_set.valid?
    assert_equal vehicle_usage_set.time_window_start, 8 * 3_600
  end

  test 'should update outdated for rest' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    customer = vehicle_usage_set.customer
    vehicle_usage = vehicle_usage_set.vehicle_usages[0]
    vehicle_usage.rest_duration = vehicle_usage.rest_start = vehicle_usage.rest_stop = nil
    vehicle_usage.save!
    nb_vu_no_rest = vehicle_usage_set.vehicle_usages.select{ |vu| vu.rest_duration.nil? && vu.rest_start.nil? && vu.rest_stop.nil? }.size
    assert nb_vu_no_rest > 0
    nb = (customer.vehicles.size - nb_vu_no_rest) * vehicle_usage_set.plannings.size
    assert nb > 0

    assert_difference('Stop.count', -nb) do
      vehicle_usage_set.vehicle_usages[0].routes[-1].compute
      vehicle_usage_set.vehicle_usages[0].routes[-1].outdated = false
      assert !vehicle_usage_set.rest_duration.nil?

      vehicle_usage_set.rest_duration = vehicle_usage_set.rest_start = vehicle_usage_set.rest_stop = nil
      vehicle_usage_set.save!
      vehicle_usage_set.customer.save!
      assert vehicle_usage_set.vehicle_usages[0].routes[-1].outdated
    end
  end

  test 'should update outdated for time_window_start' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.time_window_start = '09:00:00'
    assert_not vehicle_usage_set.vehicle_usages[0].routes[-1].outdated
    vehicle_usage_set.save!
    assert vehicle_usage_set.vehicle_usages[0].routes[-1].outdated
  end

  test 'should delete in use' do
    assert_difference('VehicleUsageSet.count', -1) do
      customers(:customer_one).vehicle_usage_sets.delete(vehicle_usage_sets(:vehicle_usage_set_one))
    end
  end

  test 'should keep at least one' do
    customer = customers(:customer_one)
    customer.vehicle_usage_sets[0..-2].each(&:destroy)
    customer.reload
    assert_equal 1, customer.vehicle_usage_sets.size
    assert !customer.vehicle_usage_sets[0].destroy
  end

  test 'should update outdated if service time or work time changed' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    route = vehicle_usage_set.vehicle_usages.sample.routes.take
    assert !route.outdated
    [:service_time_start, :service_time_end, :work_time].shuffle.each do |attr|
      assert vehicle_usage_set.send(attr).nil?
      vehicle_usage_set.update! attr => 10.minutes.to_i
      assert route.reload.outdated
    end
  end

  test 'setting a rest duration requires time start and stop' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.update! rest_start: nil, rest_stop: nil, rest_duration: nil
    assert vehicle_usage_set.valid?
    vehicle_usage_set.rest_duration = 15.minutes.to_i
    assert !vehicle_usage_set.valid?
    assert_equal [:rest_start, :rest_stop], vehicle_usage_set.errors.attribute_names
    vehicle_usage_set.rest_start = 10.hours.to_i
    vehicle_usage_set.rest_stop = 11.hours.to_i
    assert vehicle_usage_set.valid?
  end

  test 'should validate work time in relation to the working time range and service range' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: '18:00', work_time: '09:00'
    assert vehicle_usage_set.valid?
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: '18:00', work_time: '12:00'
    assert_not vehicle_usage_set.valid?
    assert_equal [:work_time], vehicle_usage_set.errors.attribute_names
    vehicle_usage_set.update time_window_start: '08:00', time_window_end: '18:00', service_time_start: '01:00', service_time_end: '01:00', work_time: '09:00'
    assert_not vehicle_usage_set.valid?
    assert_equal [:work_time], vehicle_usage_set.errors.attribute_names
  end

  test 'rest stop should not be after rest start' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)

    assert_raises ActiveRecord::RecordInvalid do
      vehicle_usage_set.update! rest_stop: '09:00', rest_start: '10:00'
    end
  end

  test 'time_window_end should not be after time_window_start' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)

    assert_raises ActiveRecord::RecordInvalid do
      vehicle_usage_set.update! time_window_end: '09:00', time_window_start: '10:00'
    end
  end

  test 'should validate cost_distance as float' do
    @vehicle_usage_set.cost_distance = 10.5
    assert @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_distance = '10,5'
    assert @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_distance = 'not a float'
    assert_not @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_distance = nil
    assert @vehicle_usage_set.valid?
  end

  test 'should validate cost_fixed as float' do
    @vehicle_usage_set.cost_fixed = 15.75
    assert @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_fixed = '15,75'
    assert @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_fixed = 'not a float'
    assert_not @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_fixed = nil
    assert @vehicle_usage_set.valid?
  end

  test 'should validate cost_time as float' do
    @vehicle_usage_set.cost_time = 20.25
    assert @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_time = '20,25'
    assert @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_time = 'not a float'
    assert_not @vehicle_usage_set.valid?

    @vehicle_usage_set.cost_time = nil
    assert @vehicle_usage_set.valid?
  end

  test 'should accept integer values for costs' do
    @vehicle_usage_set.cost_distance = 10
    @vehicle_usage_set.cost_fixed = 15
    @vehicle_usage_set.cost_time = 20
    assert @vehicle_usage_set.valid?
  end

  test 'should accept zero values for costs' do
    @vehicle_usage_set.cost_distance = 0
    @vehicle_usage_set.cost_fixed = 0
    @vehicle_usage_set.cost_time = 0
    assert @vehicle_usage_set.valid?
  end

  test 'should reject negative values for costs' do
    @vehicle_usage_set.cost_distance = -10.5
    @vehicle_usage_set.cost_fixed = -15.75
    @vehicle_usage_set.cost_time = -20.25
    assert_not @vehicle_usage_set.valid?
  end

  test 'should inherit costs from vehicle_usage_set' do
    @vehicle_usage_set.update!(
      cost_distance: 10.5,
      cost_fixed: 15.75,
      cost_time: 20.25
    )

    vehicle_usage = @vehicle_usage_set.vehicle_usages.first
    assert_equal 10.5, vehicle_usage.default_cost_distance
    assert_equal 15.75, vehicle_usage.default_cost_fixed
    assert_equal 20.25, vehicle_usage.default_cost_time
  end

  test 'vehicle_usages inherit max_reload from vehicle_usage_set when nil' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.update!(max_reload: 2)

    vu = vehicle_usage_set.vehicle_usages.first
    vu.update!(max_reload: nil)

    assert_equal 2, vu.default_max_reload
  end

  test 'vehicle_usage max_reload overrides vehicle_usage_set max_reload' do
    vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    vehicle_usage_set.update!(max_reload: 2)

    vu = vehicle_usage_set.vehicle_usages.first
    vu.update!(max_reload: 4)

    assert_equal 4, vu.default_max_reload
  end
end
