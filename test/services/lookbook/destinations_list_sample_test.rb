# frozen_string_literal: true

require 'test_helper'

class LookbookDestinationsListSampleTest < ActiveSupport::TestCase
  test 'sample destinations expose list helpers data' do
    destination = Lookbook::DestinationsListSample.destinations_for.first

    assert_predicate destination, :position?
    assert_equal 'house', destination.geocoding_level
    assert_equal 2, destination.visits.size
    assert_equal 2, destination.tags.size
  end

  test 'sample customer satisfies destinations list column catalog' do
    customer = Lookbook::DestinationsListSample.customer

    assert_includes Preferences::Catalog.destinations_list_allowed_column_ids(customer), 'visit_tags'
  end

  test 'sample tags expose default icon and color for list badge helpers' do
    destination = Lookbook::DestinationsListSample.destinations_for.first
    urgent = destination.tags.find { |tag| tag.label == 'Urgent' }
    retail = destination.tags.find { |tag| tag.label == 'Retail' }

    assert_equal Planner::Application.config.destination_icon_default, urgent.default_icon
    assert_equal '#c0392b', urgent.default_color
    assert_equal 'fa-shopping-bag', retail.default_icon
  end
end
