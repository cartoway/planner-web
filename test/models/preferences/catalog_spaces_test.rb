# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogSpacesTest < ActiveSupport::TestCase
  test 'normalize_spaces fills every space key with visible and action defaults' do
    out = Preferences::Catalog.normalize_spaces({})
    assert_equal Preferences::Catalog::SPACE_KEYS.sort, out.keys.sort
    assert out['plannings']['visible']
    assert_not out['plannings']['usable']
    assert_includes out['operations']['actions']['segments'], 'export'
    assert_includes out['tags']['actions']['segments'], 'delete_destinations_by_tags'
  end

  test 'merge_spaces_with_params maps active disabled and hidden access tiers' do
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

  test 'merge_spaces_with_params maps operation action tiers when space is active' do
    seed = Preferences::Catalog.default_spaces
    out = Preferences::Catalog.merge_spaces_with_params(
      seed,
      {
        'spaces_active' => %w[operations],
        'spaces_actions' => {
          'operations' => {
            'active' => %w[sync export],
            'disabled' => %w[transmit],
            'hidden' => %w[destroy]
          }
        }
      }
    )
    controls = out['operations']['actions']['segment_controls']
    assert controls['sync']['usable']
    assert controls['export']['usable']
    assert controls['transmit']['visible']
    assert_not controls['transmit']['usable']
    assert_not controls['destroy']['visible']
  end

  test 'default_space_entry mirrors visible usable and edit action' do
    open = Preferences::Catalog::Spaces.default_space_entry(
      'plannings', visible: true, usable: true, actions_all_usable: true
    )
    locked = Preferences::Catalog::Spaces.default_space_entry(
      'destination', visible: true, usable: false, actions_all_usable: false
    )
    assert open['usable']
    assert Preferences::Catalog::Spaces.space_action_usable_in?(open, 'edit')
    assert locked['visible']
    assert_not locked['usable']
    assert_not Preferences::Catalog::Spaces.space_action_usable_in?(locked, 'edit')
  end

  test 'space_action_usable_in? follows edit action tiers' do
    spaces = Preferences::Catalog.merge_spaces_with_params(
      Preferences::Catalog.default_spaces,
      {
        'spaces_active' => %w[plannings destination],
        'spaces_actions' => {
          'plannings' => { 'active' => %w[edit] },
          'destination' => { 'disabled' => %w[edit] }
        }
      }
    )
    assert Preferences::Catalog::Spaces.space_action_usable_in?(spaces['plannings'], 'edit')
    assert_not Preferences::Catalog::Spaces.space_action_usable_in?(spaces['destination'], 'edit')
  end

  test 'disabling or hiding a space keeps stored action controls but blocks usable_in?' do
    seed = Preferences::Catalog.merge_spaces_with_params(
      Preferences::Catalog.default_spaces,
      {
        'spaces_active' => %w[operations],
        'spaces_actions' => {
          'operations' => {
            'active' => %w[sync export],
            'disabled' => %w[transmit],
            'hidden' => %w[destroy]
          }
        }
      }
    )
    stored = seed['operations']['actions']['segment_controls'].deep_dup

    disabled = Preferences::Catalog.merge_spaces_with_params(
      seed,
      { 'spaces_active' => [], 'spaces_disabled' => %w[operations] }
    )
    assert_equal stored, disabled['operations']['actions']['segment_controls']
    assert disabled['operations']['visible']
    assert_not disabled['operations']['usable']
    assert_not Preferences::Catalog::Spaces.space_action_usable_in?(disabled['operations'], 'sync')

    hidden = Preferences::Catalog.merge_spaces_with_params(
      seed,
      { 'spaces_active' => [], 'spaces_disabled' => [] }
    )
    assert_equal stored, hidden['operations']['actions']['segment_controls']
    assert_not hidden['operations']['visible']
    assert_not Preferences::Catalog::Spaces.space_action_usable_in?(hidden['operations'], 'sync')

    reenabled = Preferences::Catalog.merge_spaces_with_params(
      disabled,
      {
        'spaces_active' => %w[operations],
        'spaces_actions' => {
          'operations' => {
            'active' => %w[sync export],
            'disabled' => %w[transmit],
            'hidden' => %w[destroy]
          }
        }
      }
    )
    assert_equal stored, reenabled['operations']['actions']['segment_controls']
    assert Preferences::Catalog::Spaces.space_action_usable_in?(reenabled['operations'], 'sync')
    assert_not Preferences::Catalog::Spaces.space_action_usable_in?(reenabled['operations'], 'destroy')
  end
end
