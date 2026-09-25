# frozen_string_literal: true

require 'test_helper'

class DestinationListPageTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @scope = @customer.destinations.reorder(
      Arel.sql('destinations.geocoding_accuracy ASC NULLS LAST, destinations.id ASC')
    )
  end

  test 'for returns the 1-based page in list order' do
    ids = @scope.map(&:id)
    target = ids.last
    assert ids.size > 1

    assert_equal ids.size, DestinationListPage.for(scope: @scope, destination_id: target, per_page: 1)
    assert_equal 1, DestinationListPage.for(scope: @scope, destination_id: ids.first, per_page: 2)
    assert_nil DestinationListPage.for(scope: @scope, destination_id: 0, per_page: 25)
  end

  test 'for ranks each destination once when the scope joins tags' do
    scope = @customer.destinations.joins(:tags).distinct.reorder(
      Arel.sql('destinations.name ASC NULLS LAST, destinations.id ASC')
    )
    ids = scope.map(&:id)
    skip 'no tagged destinations' if ids.empty?

    target = ids.last
    assert_equal (ids.index(target) / 1) + 1,
      DestinationListPage.for(scope: scope, destination_id: target, per_page: 1)
  end
end
