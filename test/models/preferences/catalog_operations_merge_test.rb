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

    assert out['stop']['segment_controls']['active_stop']['visible']
    assert out['stop']['segment_controls']['move_stop']['visible']
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
    assert_not out['stop']['segment_controls']['active_stop']['visible']
    assert_not out['stop']['segment_controls']['move_stop']['visible']
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
    seed['stop']['segment_controls']['lock_stop'] = { 'visible' => true, 'usable' => true }
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
    _active, disabled, hidden = dummy.operations_tier_split('stop')
    assert_equal [], hidden
    assert_includes disabled, 'active_stop'
    assert_includes disabled, 'move_stop'
    assert_includes disabled, 'lock_stop'
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
    assert_equal %w[lock_stop active_stop move_stop], disabled
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
    assert_equal %w[external_callback], hidden
    # Catalog ids not listed in segment_controls use Operations.normalize_zone defaults (visible, not usable → disabled).
    sp = Preferences::Catalog::OPERATION_GROUPS_PLANNING
    assert_equal %w[optimize], active
    assert_equal((sp - %w[optimize external_callback]).sort, disabled.sort)
  end

  test 'normalize_operations empty hash defaults every segment to disabled tier' do
    out = Preferences::Catalog.normalize_operations({})
    Preferences::Catalog::OPERATION_GROUPS_PLANNING.each do |id|
      assert out['planning']['segment_controls'][id]['visible'], id
      assert_not out['planning']['segment_controls'][id]['usable'], id
    end
    Preferences::Catalog::OPERATION_GROUPS_ROUTE.each do |id|
      assert out['route']['segment_controls'][id]['visible'], id
      assert_not out['route']['segment_controls'][id]['usable'], id
    end
    Preferences::Catalog::OPERATION_GROUPS_STOP.each do |id|
      assert out['stop']['segment_controls'][id]['visible'], id
      assert_not out['stop']['segment_controls'][id]['usable'], id
    end
  end

  test 'new_role_admin_operations_seed matches default_operations when YAML omits new_role override' do
    prev = Rails.application.config.default_permissions_config
    cfg = prev.deep_dup
    cfg['new_role'] = { 'operations' => nil, 'forms' => nil }
    Rails.application.config.default_permissions_config = cfg
    seed = Preferences::Catalog.new_role_admin_operations_seed
    assert_equal(
      Preferences::Catalog.normalize_operations(Preferences::Catalog.default_operations),
      Preferences::Catalog.normalize_operations(seed)
    )
  ensure
    Rails.application.config.default_permissions_config = prev
  end

  test 'baseline_role_operations_json uses disabled tier when default_role.operations is null' do
    prev = Rails.application.config.default_new_reseller_role_config
    Rails.application.config.default_new_reseller_role_config = {
      'default_role' => {
        'ref' => 'default',
        'operations' => nil,
        'forms' => nil
      }
    }
    out = Preferences::Catalog.baseline_role_operations_json
    %w[planning route stop].each do |zone|
      allowed = case zone
                when 'route' then Preferences::Catalog::OPERATION_GROUPS_ROUTE
                when 'stop' then Preferences::Catalog::OPERATION_GROUPS_STOP
                else Preferences::Catalog::OPERATION_GROUPS_PLANNING
                end
      allowed.each do |id|
        assert out[zone]['segment_controls'][id]['visible'], "#{zone} #{id} visible"
        assert_not out[zone]['segment_controls'][id]['usable'], "#{zone} #{id} usable"
      end
    end
  ensure
    Rails.application.config.default_new_reseller_role_config = prev
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

  test 'normalize_forms uses NORMALIZE_FORM_* defaults for sparse hashes' do
    dv = Preferences::Catalog::Forms::NORMALIZE_FORM_VISIBLE_DEFAULT
    du = Preferences::Catalog::Forms::NORMALIZE_FORM_USABLE_DEFAULT
    out = Preferences::Catalog.normalize_forms({ 'plannings' => { 'visible' => true } })
    assert_equal dv, out['plannings']['visible']
    assert_equal du, out['plannings']['usable']

    filled = Preferences::Catalog.normalize_forms({ 'plannings' => { 'visible' => true, 'usable' => true } })
    assert filled['destinations']['visible']
    assert_not filled['destinations']['usable']
  end

  test 'normalize_forms empty hash is still default_forms (full access catalog seed)' do
    assert_equal Preferences::Catalog.default_forms, Preferences::Catalog.normalize_forms({})
  end
end
