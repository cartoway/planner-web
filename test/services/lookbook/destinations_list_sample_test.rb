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
end
