# frozen_string_literal: true

require 'test_helper'
require 'font_awesome'

class FontAwesomeTest < ActiveSupport::TestCase
  test 'normalized_fa_icon_token matches tags/roles storage format' do
    assert_nil FontAwesome.normalized_fa_icon_token(nil)
    assert_nil FontAwesome.normalized_fa_icon_token('')
    assert_equal 'fa-user', FontAwesome.normalized_fa_icon_token('user')
    assert_equal 'fa-user', FontAwesome.normalized_fa_icon_token('fa-user')
  end

  test 'icon_token_in_table? uses ICONS_TABLE allowlist' do
    assert FontAwesome.icon_token_in_table?('truck')
    assert_not FontAwesome.icon_token_in_table?('not-a-real-glyph-name-xyz')
  end

  test 'icons_table_grouped matches tag preferred + rest split' do
    grouped = FontAwesome.icons_table_grouped
    assert_equal FontAwesome::ICONS_TABLE_TAG, grouped[0]
    assert_equal FontAwesome::ICONS_TABLE - FontAwesome::ICONS_TABLE_TAG, grouped[1]
  end
end
