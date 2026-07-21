# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogDestinationsListTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'default active columns include address fields, geocoding and only the first deliverable unit' do
    active = Preferences::Catalog::DestinationsList.default_active_for(@customer)
    units = @customer.deliverable_units.to_a
    assert units.size > 1, 'fixture customer should have several deliverable units'

    expected_static = %w[name street postalcode city geocoding]
    assert_equal expected_static, active & expected_static
    assert_not_includes active, 'ref'
    assert_not_includes active, 'visit_ref'

    first_unit_col = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(units.first)
    assert_includes active, first_unit_col
    units.drop(1).each do |unit|
      assert_not_includes active, Preferences::Catalog::DestinationsList.deliverable_unit_column_id(unit)
    end
    assert_operator active.size, :<=, Preferences::Catalog::DestinationsList::MAX_ACTIVE
  end

  test 'normalize_zone caps active columns at MAX_ACTIVE' do
    allowed = Preferences::Catalog::DestinationsList.allowed_column_ids(@customer)
    oversized = allowed.first(Preferences::Catalog::DestinationsList::MAX_ACTIVE + 3)
    assert oversized.size > Preferences::Catalog::DestinationsList::MAX_ACTIVE

    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => oversized, 'hidden' => [] },
      customer: @customer
    )
    assert_equal Preferences::Catalog::DestinationsList::MAX_ACTIVE, normalized['active'].size
    assert_equal oversized.first(Preferences::Catalog::DestinationsList::MAX_ACTIVE), normalized['active']
    oversized.drop(Preferences::Catalog::DestinationsList::MAX_ACTIVE).each do |col|
      assert_includes normalized['hidden'], col
    end
  end

  test 'normalize_zone keeps defaults when active and hidden are both empty' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone({ 'active' => [], 'hidden' => [] })
    assert normalized['active'].present?
  end

  test 'normalize_zone allows empty active when user hid every column' do
    allowed = Preferences::Catalog::DestinationsList.allowed_column_ids(@customer)
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => [], 'hidden' => allowed },
      customer: @customer
    )
    assert_empty normalized['active']
    assert_equal allowed.to_set, normalized['hidden'].to_set
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

  test 'normalize_zone with customer keeps new deliverable unit columns hidden until enabled' do
    units = @customer.deliverable_units.to_a
    first_col = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(units.first)
    second_col = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(units.second)
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => %w[name street postalcode city] + [first_col], 'hidden' => [] },
      customer: @customer
    )
    assert_includes normalized['active'], first_col
    assert_includes normalized['hidden'], second_col
    assert_not_includes normalized['active'], second_col
  end

  test 'normalize_zone falls back to limited default active when empty' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone(
      { 'active' => [], 'hidden' => [] },
      customer: @customer
    )
    assert_equal Preferences::Catalog::DestinationsList.default_active_for(@customer), normalized['active']
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

  test 'normalize_headers defaults destinations_index to legacy' do
    normalized = Preferences::Catalog.normalize_headers({})
    assert_equal Preferences::Catalog::Headers::DESTINATIONS_INDEX_LEGACY, normalized['destinations_index']

    normalized_v2 = Preferences::Catalog.normalize_headers({ 'destinations_index' => 'v2' })
    assert_equal Preferences::Catalog::Headers::DESTINATIONS_INDEX_V2, normalized_v2['destinations_index']

    normalized_invalid = Preferences::Catalog.normalize_headers({ 'destinations_index' => 'unknown' })
    assert_equal Preferences::Catalog::Headers::DESTINATIONS_INDEX_LEGACY, normalized_invalid['destinations_index']
  end
end
