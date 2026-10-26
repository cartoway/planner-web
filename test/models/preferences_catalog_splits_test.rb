# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogSplitsTest < ActiveSupport::TestCase
  class SpacesSplitDummy
    include PreferencesCatalogSplits

    attr_accessor :spaces

    def read_spaces_hash
      spaces.is_a?(Hash) ? spaces.deep_stringify_keys : {}
    end
  end

  test 'spaces_resources_three_way_split places missing catalog keys in disabled tier not active' do
    dummy = SpacesSplitDummy.new
    dummy.spaces = {
      'plannings' => { 'visible' => true, 'usable' => true },
      'destination' => { 'visible' => true, 'usable' => true },
      'vehicle_usages' => { 'visible' => true, 'usable' => true }
    }

    active, disabled, hidden = dummy.spaces_resources_three_way_split

    assert_includes disabled, 'stores'
    assert_includes disabled, 'customer'
    assert_includes disabled, 'operations'
    assert_not_includes active, 'stores'
    assert_not_includes hidden, 'stores'
  end
end
