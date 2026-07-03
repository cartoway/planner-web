# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogDestinationsListTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'default active columns respect customer flags' do
    active = Preferences::Catalog::DestinationsList.default_active_for(@customer)
    assert_includes active, 'name'
    assert_includes active, 'street'
    assert_includes active, 'postalcode'
    assert_includes active, 'city'
    assert_includes active, 'geocoding'
    @customer.deliverable_units.each do |unit|
      assert_includes active, Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
    end
  end

  test 'normalize_zone keeps at least one active column' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone({ 'active' => [], 'hidden' => [] })
    assert normalized['active'].present?
  end

  test 'allowed column ids include visit_tags when customer is editable' do
    assert_includes Preferences::Catalog::DestinationsList.allowed_column_ids(@customer), 'visit_tags'
  end

  test 'allowed column ids include one column per deliverable unit' do
    allowed = Preferences::Catalog::DestinationsList.allowed_column_ids(@customer.reload)
    @customer.deliverable_units.each do |unit|
      col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
      assert_includes allowed, col_id
    end
  end

  test 'normalize_zone with customer keeps deliverable unit columns in active' do
    unit = @customer.deliverable_units.first
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => ['name'] + [col_id], 'hidden' => [] },
      customer: @customer
    )
    assert_includes normalized['active'], col_id
  end

  test 'normalize_zone with customer auto-activates new deliverable unit columns' do
    unit = @customer.deliverable_units.first
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => ['name'], 'hidden' => [] },
      customer: @customer
    )
    assert_includes normalized['active'], col_id
  end

  test 'normalize_zone without customer strips deliverable unit columns' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => %w[name deliverable_unit_1], 'hidden' => [] }
    )
    assert_not_includes normalized['active'], 'deliverable_unit_1'
  end

  test 'visit_scoped_column? covers visit tags, visits and deliverable unit columns' do
    unit = @customer.deliverable_units.first
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
    assert Preferences::Catalog::DestinationsList.visit_scoped_column?('visit_tags')
    assert Preferences::Catalog::DestinationsList.visit_scoped_column?('visit_ref')
    assert Preferences::Catalog::DestinationsList.visit_scoped_column?(col_id)
    assert_not Preferences::Catalog::DestinationsList.visit_scoped_column?('name')
  end

  test 'normalize_zone expands legacy address column into street postalcode city' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => %w[name address ref], 'hidden' => [] },
      customer: @customer
    )
    assert_equal %w[name street postalcode city ref], normalized['active'] & %w[name street postalcode city ref]
    assert_not_includes normalized['active'], 'address'
  end

  test 'normalize_zone remaps legacy visits column to visit_ref' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => %w[name visits], 'hidden' => [] },
      customer: @customer
    )
    assert_includes normalized['active'], 'visit_ref'
    assert_not_includes normalized['active'], 'visits'
  end

  test 'normalize_zone places visit_ref before visit_tags in active columns' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => %w[name visit_tags visit_ref], 'hidden' => [] },
      customer: @customer
    )
    assert_equal %w[name visit_ref visit_tags], normalized['active'] & %w[name visit_ref visit_tags]
  end

  test 'normalize_headers includes destinations_list zone' do
    normalized = Preferences::Catalog.normalize_headers({})
    assert_equal Preferences::Catalog::DestinationsList::DEFAULT_ACTIVE, normalized['destinations_list']['active']
  end
end
