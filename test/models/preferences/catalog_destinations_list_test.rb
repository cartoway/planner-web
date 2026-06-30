# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogDestinationsListTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'default active columns respect customer flags' do
    active = Preferences::Catalog::DestinationsList.default_active_for(@customer)
    assert_includes active, 'name'
    assert_includes active, 'address'
    assert_includes active, 'geocoding'
  end

  test 'normalize_zone keeps at least one active column' do
    normalized = Preferences::Catalog::DestinationsList.normalize_zone({ 'active' => [], 'hidden' => [] })
    assert normalized['active'].present?
  end

  test 'allowed column ids include visit_tags when customer is editable' do
    assert_includes Preferences::Catalog::DestinationsList.allowed_column_ids(@customer), 'visit_tags'
  end

  test 'normalize_headers includes destinations_list zone' do
    normalized = Preferences::Catalog.normalize_headers({})
    assert_equal Preferences::Catalog::DestinationsList::DEFAULT_ACTIVE, normalized['destinations_list']['active']
  end
end
