# frozen_string_literal: true

require 'test_helper'

class DestinationsListSortTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'parse returns nil when sort column is blank' do
    assert_nil DestinationsListSort.parse({}, customer: @customer)
    assert_nil DestinationsListSort.parse({ sort: 'unknown' }, customer: @customer)
  end

  test 'parse accepts allowed destination columns' do
    sort = DestinationsListSort.parse({ sort: 'name', direction: 'desc' }, customer: @customer)
    assert_equal 'name', sort.column_id
    assert_equal 'desc', sort.direction
  end

  test 'parse accepts deliverable unit columns' do
    unit = @customer.deliverable_units.first
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
    sort = DestinationsListSort.parse({ sort: col_id }, customer: @customer)
    assert_equal col_id, sort.column_id
    assert_equal 'asc', sort.direction
  end

  test 'apply orders destinations by name' do
    destination_a = destinations(:destination_unaffected_one)
    destination_b = destinations(:destination_one)
    destination_a.update_columns(name: 'AAA sort test')
    destination_b.update_columns(name: 'ZZZ sort test')

    scope = @customer.destinations.where(id: [destination_a.id, destination_b.id])
    sorted = DestinationsListSort.new(column_id: 'name', direction: 'asc', customer: @customer).apply(scope)
    assert_equal [destination_a.id, destination_b.id], sorted.pluck(:id)
  end

  test 'next_direction_for toggles active column and resets others to asc' do
    sort = DestinationsListSort.new(column_id: 'name', direction: 'asc', customer: @customer)
    assert_equal 'desc', sort.next_direction_for('name')
    assert_equal 'asc', sort.next_direction_for('address')
  end
end
