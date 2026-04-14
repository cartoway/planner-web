# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogOperationsMergeTest < ActiveSupport::TestCase
  class OpSplitDummy
    include PreferencesCatalogSplits
    attr_accessor :operations

    def read_operations_hash
      operations.is_a?(Hash) ? operations.deep_stringify_keys : {}
    end
  end

  test 'merge_operations_with_params sets active vs hidden from first column when disabled column omitted' do
    seed = Preferences::Catalog.default_operations.deep_dup
    out = Preferences::Catalog.merge_operations_with_params(
      seed,
      { 'planning' => %w[optimize], 'route' => %w[export] }
    )

    assert out['planning']['segment_controls']['optimize']['visible']
    assert out['planning']['segment_controls']['optimize']['usable']
    assert_not out['planning']['segment_controls']['zoning']['visible']
    assert_not out['planning']['segment_controls']['zoning']['usable']

    assert out['route']['segment_controls']['export']['visible']
    assert out['route']['segment_controls']['export']['usable']
    assert_not out['route']['segment_controls']['vehicle_usage']['visible']
    assert_not out['route']['segment_controls']['vehicle_usage']['usable']

    assert_not out['stop']['segment_controls']['lock_stop']['visible']
    assert_not out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'merge_operations_with_params maps disabled column to visible but not usable' do
    seed = Preferences::Catalog.default_operations.deep_dup
    out = Preferences::Catalog.merge_operations_with_params(
      seed,
      {
        'planning' => %w[optimize],
        'planning_disabled' => %w[zoning],
        'route' => %w[export],
        'route_disabled' => %w[vehicle_usage]
      }
    )

    assert out['planning']['segment_controls']['optimize']['visible']
    assert out['planning']['segment_controls']['optimize']['usable']

    assert out['planning']['segment_controls']['zoning']['visible']
    assert_not out['planning']['segment_controls']['zoning']['usable']

    assert out['route']['segment_controls']['export']['visible']
    assert out['route']['segment_controls']['export']['usable']

    assert out['route']['segment_controls']['vehicle_usage']['visible']
    assert_not out['route']['segment_controls']['vehicle_usage']['usable']
  end

  test 'default_operations hides stop lock_stop until enabled via merge' do
    defs = Preferences::Catalog.default_operations
    assert_not defs['stop']['segment_controls']['lock_stop']['visible']
    assert_not defs['stop']['segment_controls']['lock_stop']['usable']

    out = Preferences::Catalog.merge_operations_with_params(
      defs.deep_dup,
      { 'stop' => %w[lock_stop] }
    )
    assert out['stop']['segment_controls']['lock_stop']['visible']
    assert out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'merge_operations_with_params applies stop disabled when active column is omitted from params' do
    seed = Preferences::Catalog.default_operations.deep_dup
    out = Preferences::Catalog.merge_operations_with_params(
      seed,
      { 'stop_disabled' => %w[lock_stop] }
    )
    assert out['stop']['segment_controls']['lock_stop']['visible']
    assert_not out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'merge_operations_with_params applies stop hidden when active and disabled columns are omitted' do
    seed = Preferences::Catalog.default_operations.deep_dup
    seed['stop']['segment_controls']['lock_stop'] = { 'visible' => true, 'usable' => true, 'customizable' => true }
    out = Preferences::Catalog.merge_operations_with_params(
      seed,
      { 'stop_hidden' => %w[lock_stop] }
    )
    assert_not out['stop']['segment_controls']['lock_stop']['visible']
    assert_not out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'operations_tier_split stop uses catalog defaults when operations JSON has no stop key' do
    dummy = OpSplitDummy.new
    dummy.operations = {
      'planning' => Preferences::Catalog.default_operations['planning'],
      'route' => Preferences::Catalog.default_operations['route']
    }
    _active, _disabled, hidden = dummy.operations_tier_split('stop')
    assert_includes hidden, 'lock_stop'
  end

  test 'operations_tier_split stop zone respects lock_stop visibility' do
    dummy = OpSplitDummy.new
    dummy.operations = {
      'stop' => {
        'segments' => %w[lock_stop],
        'segment_controls' => {
          'lock_stop' => { 'visible' => true, 'usable' => false }
        }
      }
    }
    active, disabled, hidden = dummy.operations_tier_split('stop')
    assert_equal [], active
    assert_equal %w[lock_stop], disabled
    assert_equal [], hidden
  end

  test 'operations_tier_split groups ids into active disabled and hidden buckets' do
    dummy = OpSplitDummy.new
    dummy.operations = {
      'planning' => {
        'segments' => %w[zoning optimize external_callback],
        'segment_controls' => {
          'optimize' => { 'visible' => true, 'usable' => true },
          'zoning' => { 'visible' => true, 'usable' => false },
          'external_callback' => { 'visible' => false, 'usable' => false }
        }
      }
    }
    active, disabled, hidden = dummy.operations_tier_split('planning')
    assert_equal %w[zoning], disabled
    assert_equal %w[external_callback], hidden
    # After explicit `segments` order, any catalog id not yet seen uses default controls (visible + usable → active).
    sp = Preferences::Catalog::OPERATION_GROUPS_PLANNING
    assert_equal %w[optimize] + (sp - %w[zoning optimize external_callback]), active
  end

  test 'header catalogs include optional wait_time and visits_duration ids' do
    assert_includes Preferences::Catalog::HEADER_PLANNING, 'wait_time'
    assert_includes Preferences::Catalog::HEADER_PLANNING, 'visits_duration'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'wait_time'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'visits_duration'
  end

  test 'default_headers omits wait_time and visits_duration from active until enabled in admin' do
    dh = Preferences::Catalog.default_headers
    assert_not_includes dh['planning']['active'], 'wait_time'
    assert_includes dh['planning']['hidden'], 'wait_time'
    assert_not_includes dh['route']['active'], 'wait_time'
    assert_includes dh['route']['hidden'], 'wait_time'
  end

  test 'normalize_headers persists active and hidden lists per zone' do
    hp = Preferences::Catalog::HEADER_PLANNING
    hr = Preferences::Catalog::HEADER_ROUTE
    raw = {
      'planning' => { 'active' => %w[stops wait_time duration], 'hidden' => [] },
      'route' => { 'active' => %w[wait_time stops], 'hidden' => [] }
    }
    normalized = Preferences::Catalog.normalize_headers(raw)
    assert_equal %w[stops wait_time duration], normalized['planning']['active']
    assert_equal (hp - %w[stops wait_time duration]).sort, normalized['planning']['hidden'].sort
    assert_equal %w[wait_time stops], normalized['route']['active']
    assert_equal (hr - %w[wait_time stops]).sort, normalized['route']['hidden'].sort
  end

  test 'merge_forms_with_params maps active disabled and hidden to visible and usable' do
    seed = Preferences::Catalog.default_forms
    out = Preferences::Catalog.merge_forms_with_params(
      seed,
      { 'forms_active' => %w[plannings], 'forms_disabled' => %w[visits] }
    )
    assert out['plannings']['visible']
    assert out['plannings']['usable']
    assert out['visits']['visible']
    assert_not out['visits']['usable']
    assert_not out['destinations']['visible']
    assert_not out['destinations']['usable']
  end
end
