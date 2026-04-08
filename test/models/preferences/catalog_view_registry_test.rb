# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogViewRegistryTest < ActiveSupport::TestCase
  test 'header_block_partial maps catalog ids to plannings or routes data_blocks partials' do
    Preferences::Catalog::HEADER_PLANNING.each do |key|
      assert_equal "plannings/data_blocks/#{key}", Preferences::Catalog.header_block_partial('planning', key)
    end
    Preferences::Catalog::HEADER_ROUTE.each do |key|
      assert_equal "routes/data_blocks/#{key}", Preferences::Catalog.header_block_partial('route', key)
    end
  end

  test 'header_block_partial returns nil for unknown keys' do
    assert_nil Preferences::Catalog.header_block_partial('planning', 'not_a_real_block')
  end

  test 'toolbar_operation_partial maps planning and route operation ids' do
    assert_equal 'plannings/operations/optimize',
                 Preferences::Catalog.toolbar_operation_partial('planning', 'optimize')
    assert_equal 'plannings/operations/vehicle_usage_set',
                 Preferences::Catalog.toolbar_operation_partial('planning', 'vehicle_usage_set')
    assert_equal 'routes/operations/vehicle_usage',
                 Preferences::Catalog.toolbar_operation_partial('route', 'vehicle_usage')
  end

  test 'planning_edit_global_toolbar_operation_ids is a fixed catalog order' do
    assert_equal %w[toggle_routes toggle_route_data lock_routes export],
                 Preferences::Catalog.planning_edit_global_toolbar_operation_ids
  end
end
