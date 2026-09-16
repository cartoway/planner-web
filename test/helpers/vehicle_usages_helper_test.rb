require 'test_helper'

class VehicleUsagesHelperTest < ActionView::TestCase
  include ApplicationHelper
  include FontAwesome::Sass::Rails::ViewHelpers

  test 'store name greys the default missing-depot ban icon' do
    vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    vehicle_usage.store_start = nil
    vehicle_usage.vehicle_usage_set.store_start = nil

    html = vehicle_usage_store_name(vehicle_usage).to_s
    assert_match(/span[^>]*class="[^"]*default-color[^"]*"[^>]*>.*fa-ban/m, html)
  end
end
