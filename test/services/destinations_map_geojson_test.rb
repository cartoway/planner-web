# frozen_string_literal: true

require 'test_helper'

class DestinationsMapGeojsonTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @scope = @customer.destinations.reorder(:id)
  end

  test 'build returns compact points with page metadata' do
    payload = DestinationsMapGeojson.build(scope: @scope, per_page: 1)
    assert payload[:points].size.positive?
    id, lng, lat, page = payload[:points].first
    assert id.present?
    assert_kind_of Numeric, lng
    assert_kind_of Numeric, lat
    assert page.present?
    assert_equal 4, payload[:points].first.size
  end

  test 'build filters by bbox' do
    full = DestinationsMapGeojson.build(scope: @scope, per_page: 25)
    bbox = [-1.0, 48.0, 3.0, 50.0]
    filtered = DestinationsMapGeojson.build(scope: @scope, per_page: 25, bbox: bbox)
    assert filtered[:points].size <= full[:points].size
    filtered[:points].each do |id, lng, lat, _page|
      assert id.present?
      assert lat.between?(bbox[1], bbox[3])
      assert lng.between?(bbox[0], bbox[2])
    end
  end

  test 'bounds_only returns extent without features' do
    scope = @customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST')
    payload = DestinationsMapGeojson.build(scope: scope, per_page: 25, bounds_only: true)
    assert_equal [], payload[:features]
    assert payload[:bounds].present?
    assert_equal 2, payload[:bounds].size
  end

  test 'highlight_id is included even outside bbox' do
    destination = destinations(:destination_one)
    tiny_bbox = [destination.lng.to_f - 0.001, destination.lat.to_f - 0.001, destination.lng.to_f - 0.0005, destination.lat.to_f - 0.0005]
    payload = DestinationsMapGeojson.build(
      scope: @scope,
      per_page: 25,
      bbox: tiny_bbox,
      highlight_id: destination.id
    )
    ids = payload[:points].map(&:first)
    assert_includes ids, destination.id
  end
end
