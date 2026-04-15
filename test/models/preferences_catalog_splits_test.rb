# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogSplitsTest < ActiveSupport::TestCase
  # Minimal object with only #read_forms_hash (Role-like JSON before new FORM_RESOURCES keys exist in DB).
  class FormsSplitDummy
    include PreferencesCatalogSplits

    attr_accessor :forms

    def read_forms_hash
      forms.is_a?(Hash) ? forms.stringify_keys : {}
    end
  end

  test 'forms_resources_three_way_split places missing catalog form ids in disabled tier not active' do
    dummy = FormsSplitDummy.new
    dummy.forms = {
      'plannings' => { 'visible' => true, 'usable' => true },
      'destinations' => { 'visible' => true, 'usable' => true },
      'visits' => { 'visible' => true, 'usable' => true },
      'vehicle_usages' => { 'visible' => true, 'usable' => true }
    }

    active, disabled, hidden = dummy.forms_resources_three_way_split

    assert_includes disabled, 'stores'
    assert_not_includes active, 'stores'
    assert_not_includes hidden, 'stores'
  end
end
