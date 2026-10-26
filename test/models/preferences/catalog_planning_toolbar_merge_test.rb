# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogPlanningToolbarMergeTest < ActiveSupport::TestCase
  class OpSplitDummy
    include PreferencesCatalogSplits
    attr_accessor :planning_toolbar

    def read_planning_toolbar_hash
      planning_toolbar.is_a?(Hash) ? planning_toolbar.deep_stringify_keys : {}
    end
  end

  test 'merge_planning_toolbar_with_params sets active vs hidden from first column when disabled column omitted' do
    seed = Preferences::Catalog.default_planning_toolbar.deep_dup
    out = Preferences::Catalog.merge_planning_toolbar_with_params(
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
    assert out['stop']['segment_controls']['lock_stop']['visible']
    assert out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'merge_planning_toolbar_with_params maps disabled column to visible but not usable' do
    seed = Preferences::Catalog.default_planning_toolbar.deep_dup
    out = Preferences::Catalog.merge_planning_toolbar_with_params(
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

  test 'default_planning_toolbar enables stop lock_stop in reseller default role seed' do
    defs = Preferences::Catalog.default_planning_toolbar
    assert defs['stop']['segment_controls']['lock_stop']['visible']
    assert defs['stop']['segment_controls']['lock_stop']['usable']

    out = Preferences::Catalog.merge_planning_toolbar_with_params(
      defs.deep_dup,
      { 'stop' => %w[lock_stop] }
    )
    assert_not out['stop']['segment_controls']['active_stop']['visible']
    assert_not out['stop']['segment_controls']['move_stop']['visible']
    assert out['stop']['segment_controls']['lock_stop']['visible']
    assert out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'default_planning_toolbar includes planning_states duplicate and planning_dashboard in planning toolbar catalog' do
    defs = Preferences::Catalog.default_planning_toolbar
    assert_includes Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING, 'planning_states'
    assert_includes Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING, 'duplicate'
    assert_includes Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING, 'planning_dashboard'
    assert defs['planning']['segment_controls']['planning_states']['visible']
    assert defs['planning']['segment_controls']['planning_states']['usable']
    assert defs['planning']['segment_controls']['duplicate']['visible']
    assert defs['planning']['segment_controls']['duplicate']['usable']
    assert defs['planning']['segment_controls']['planning_dashboard']['visible']
    assert defs['planning']['segment_controls']['planning_dashboard']['usable']
  end

  test 'default_planning_toolbar enables planning activate_stops in reseller default role seed' do
    defs = Preferences::Catalog.default_planning_toolbar
    assert defs['planning']['segment_controls']['activate_stops']['visible']
    assert defs['planning']['segment_controls']['activate_stops']['usable']

    out = Preferences::Catalog.merge_planning_toolbar_with_params(
      defs.deep_dup,
      { 'planning' => %w[activate_stops] }
    )
    assert out['planning']['segment_controls']['activate_stops']['visible']
    assert out['planning']['segment_controls']['activate_stops']['usable']
  end

  test 'merge_planning_toolbar_with_params applies stop disabled when active column is omitted from params' do
    seed = Preferences::Catalog.default_planning_toolbar.deep_dup
    out = Preferences::Catalog.merge_planning_toolbar_with_params(
      seed,
      { 'stop_disabled' => %w[lock_stop] }
    )
    assert out['stop']['segment_controls']['lock_stop']['visible']
    assert_not out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'merge_planning_toolbar_with_params applies stop hidden when active and disabled columns are omitted' do
    seed = Preferences::Catalog.default_planning_toolbar.deep_dup
    seed['stop']['segment_controls']['lock_stop'] = { 'visible' => true, 'usable' => true }
    out = Preferences::Catalog.merge_planning_toolbar_with_params(
      seed,
      { 'stop_hidden' => %w[lock_stop] }
    )
    assert_not out['stop']['segment_controls']['lock_stop']['visible']
    assert_not out['stop']['segment_controls']['lock_stop']['usable']
  end

  test 'planning_toolbar_tier_split stop uses catalog defaults when operations JSON has no stop key' do
    dummy = OpSplitDummy.new
    dummy.planning_toolbar = {
      'planning' => Preferences::Catalog.default_planning_toolbar['planning'],
      'route' => Preferences::Catalog.default_planning_toolbar['route']
    }
    _active, disabled, hidden = dummy.planning_toolbar_tier_split('stop')
    assert_equal [], hidden
    assert_includes disabled, 'active_stop'
    assert_includes disabled, 'move_stop'
    assert_includes disabled, 'lock_stop'
  end

  test 'planning_toolbar_tier_split stop zone respects lock_stop visibility' do
    dummy = OpSplitDummy.new
    dummy.planning_toolbar = {
      'stop' => {
        'segments' => %w[lock_stop],
        'segment_controls' => {
          'lock_stop' => { 'visible' => true, 'usable' => false }
        }
      }
    }
    active, disabled, hidden = dummy.planning_toolbar_tier_split('stop')
    assert_equal [], active
    assert_equal %w[lock_stop active_stop move_stop], disabled
    assert_equal [], hidden
  end

  test 'planning_toolbar_tier_split groups ids into active disabled and hidden buckets' do
    dummy = OpSplitDummy.new
    dummy.planning_toolbar = {
      'planning' => {
        'segments' => %w[zoning optimize external_callback],
        'segment_controls' => {
          'optimize' => { 'visible' => true, 'usable' => true },
          'zoning' => { 'visible' => true, 'usable' => false },
          'external_callback' => { 'visible' => false, 'usable' => false }
        }
      }
    }
    active, disabled, hidden = dummy.planning_toolbar_tier_split('planning')
    assert_equal %w[external_callback], hidden
    # Catalog ids not listed in segment_controls use PlanningToolbar.normalize_zone defaults (visible, not usable → disabled).
    sp = Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING
    assert_equal %w[optimize], active
    assert_equal((sp - %w[optimize external_callback]).sort, disabled.sort)
  end

  test 'normalize_planning_toolbar empty hash defaults every segment to disabled tier' do
    out = Preferences::Catalog.normalize_planning_toolbar({})
    Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING.each do |id|
      assert out['planning']['segment_controls'][id]['visible'], id
      assert_not out['planning']['segment_controls'][id]['usable'], id
    end
    Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_ROUTE.each do |id|
      assert out['route']['segment_controls'][id]['visible'], id
      assert_not out['route']['segment_controls'][id]['usable'], id
    end
    Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_STOP.each do |id|
      assert out['stop']['segment_controls'][id]['visible'], id
      assert_not out['stop']['segment_controls'][id]['usable'], id
    end
  end

  test 'new_role_admin_planning_toolbar_seed matches default_planning_toolbar when YAML omits new_role override' do
    prev = Rails.application.config.default_permissions_config
    cfg = prev.deep_dup
    cfg['new_role'] = { 'planning_toolbar' => nil, 'spaces' => nil }
    Rails.application.config.default_permissions_config = cfg
    seed = Preferences::Catalog.new_role_admin_planning_toolbar_seed
    assert_equal(
      Preferences::Catalog.normalize_planning_toolbar(Preferences::Catalog.default_planning_toolbar),
      Preferences::Catalog.normalize_planning_toolbar(seed)
    )
  ensure
    Rails.application.config.default_permissions_config = prev
  end

  test 'baseline_role_planning_toolbar_json uses disabled tier when default_role.planning_toolbar is null' do
    prev = Rails.application.config.default_new_reseller_role_config
    Rails.application.config.default_new_reseller_role_config = {
      'default_role' => {
        'ref' => 'default',
        'planning_toolbar' => nil,
        'spaces' => nil
      }
    }
    out = Preferences::Catalog.baseline_role_planning_toolbar_json
    %w[planning route stop].each do |zone|
      allowed = case zone
                when 'route' then Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_ROUTE
                when 'stop' then Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_STOP
                else Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING
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
    assert_includes Preferences::Catalog::HEADER_PLANNING, 'total_duration'
    assert_includes Preferences::Catalog::HEADER_PLANNING, 'work_duration'
    assert_not_includes Preferences::Catalog::HEADER_PLANNING, 'duration'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'wait_time'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'visits_duration'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'total_duration'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'work_duration'
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
      'planning' => { 'active' => %w[stops wait_time total_duration work_duration], 'hidden' => [] },
      'route' => { 'active' => %w[wait_time stops], 'hidden' => [] }
    }
    normalized = Preferences::Catalog.normalize_headers(raw)
    assert_equal %w[stops wait_time total_duration work_duration], normalized['planning']['active']
    assert_equal (hp - %w[stops wait_time total_duration work_duration]).sort, normalized['planning']['hidden'].sort
    assert_equal %w[wait_time stops], normalized['route']['active']
    assert_equal (hr - %w[wait_time stops]).sort, normalized['route']['hidden'].sort
    assert_equal Preferences::Catalog::StopList::DEFAULT_ACTIVE, normalized['stop_list']['active']
    assert_equal Preferences::Catalog::DestinationsList::DEFAULT_ACTIVE, normalized['destinations_list']['active']
  end

  test 'merge_spaces_with_params maps active disabled and hidden to visible and usable' do
    seed = Preferences::Catalog.default_spaces
    out = Preferences::Catalog.merge_spaces_with_params(
      seed,
      { 'spaces_active' => %w[plannings], 'spaces_disabled' => %w[destination] }
    )
    assert out['plannings']['visible']
    assert out['plannings']['usable']
    assert out['destination']['visible']
    assert_not out['destination']['usable']
    assert_not out['stores']['visible']
    assert_not out['stores']['usable']
  end

  test 'normalize_spaces empty hash disables every space by default' do
    out = Preferences::Catalog.normalize_spaces({})
    assert out['plannings']['visible']
    assert_not out['plannings']['usable']
    assert out['operations']['visible']
    assert_not out['operations']['usable']
  end
end
