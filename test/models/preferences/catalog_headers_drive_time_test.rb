# frozen_string_literal: true

require 'test_helper'

class PreferencesCatalogHeadersDriveTimeTest < ActiveSupport::TestCase
  test 'drive_time is available in planning and route header catalogs' do
    assert_includes Preferences::Catalog::HEADER_PLANNING, 'drive_time'
    assert_includes Preferences::Catalog::HEADER_ROUTE, 'drive_time'
  end

  test 'drive_time is hidden by default in planning and route headers' do
    refute_includes Preferences::Catalog::HEADER_PLANNING_DEFAULT, 'drive_time'
    refute_includes Preferences::Catalog::HEADER_ROUTE_DEFAULT, 'drive_time'
  end
end
