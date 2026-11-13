# frozen_string_literal: true

require 'test_helper'

# Happy path: SKIP_WEBPACK stubs keep HTML renders usable without public/packs.
class SkipWebpackHelperTest < ActionView::TestCase
  include Webpacker::Helper

  test 'pack tags are empty when SKIP_WEBPACK is set' do
    skip 'set SKIP_WEBPACK=1 to exercise stubs' unless ENV['SKIP_WEBPACK'] == '1'

    assert_equal '', javascript_pack_tag('vendor')
    assert_equal '', stylesheet_pack_tag('vendor_stylesheet')
  end
end
