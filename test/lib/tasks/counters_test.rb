require 'test_helper'

class CountersTaskTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    Customer.where(id: @customer.id).update_all(
      destinations_count: 0,
      visits_count: 0,
      plannings_count: 0,
      vehicles_count: 0
    )
  end

  test 'should reset counters for all customers' do
    # Create some test data
    destination = @customer.destinations.create!(
      name: 'Test Destination',
      street: 'Test Street',
      postalcode: '12345',
      city: 'Test City'
    )

    destination.visits.create!(ref: 'TEST001')

    @customer.plannings.create!(
      name: 'Test Planning',
      vehicle_usage_set: @customer.vehicle_usage_sets.first
    )

    # Run the rake task
    Rake::Task['counters:reset'].invoke

    # Reload customer and check counters
    @customer.reload

    assert_equal 5, @customer.destinations_count
    assert_equal 5, @customer.visits_count
    assert_equal 3, @customer.plannings_count
    assert_equal 2, @customer.vehicles_count
  end

  test 'should reset counters for specific customer' do
    # Create test data
    destination = @customer.destinations.create!(
      name: 'Test Destination',
      street: 'Test Street',
      postalcode: '12345',
      city: 'Test City'
    )

    destination.visits.create!(ref: 'TEST001')

    # Run the rake task for specific customer
    Rake::Task['counters:reset_customer'].invoke(@customer.id.to_s)

    # Reload customer and check counters
    @customer.reload

    assert_equal 5, @customer.destinations_count
    assert_equal 5, @customer.visits_count
  end

  test 'should check counter consistency' do
    # Create test data
    destination = @customer.destinations.create!(
      name: 'Test Destination',
      street: 'Test Street',
      postalcode: '12345',
      city: 'Test City'
    )

    destination.visits.create!(ref: 'TEST001')

    # Run the check task
    Rake::Task['counters:check'].invoke

    # The task should detect inconsistency since we manually set counters to 0
    # but we have actual data
    @customer.reload

    # After the check, counters should still be inconsistent (check doesn't fix)
    assert_equal 1, @customer.destinations_count
    assert_equal 1, @customer.visits_count
  end

  teardown do
    # Clean up any created test data
    @customer.destinations.where(name: 'Test Destination').destroy_all
    @customer.plannings.where(name: 'Test Planning').destroy_all
    @customer.vehicles.where(name: 'Test Vehicle').destroy_all

    # Reset rake tasks for next test
    Rake::Task['counters:reset'].reenable
    Rake::Task['counters:reset_customer'].reenable
    Rake::Task['counters:check'].reenable
  end
end
