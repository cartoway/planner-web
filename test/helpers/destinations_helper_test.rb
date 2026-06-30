require 'test_helper'

class DestinationsHelperTest < ActionView::TestCase
  include DestinationsHelper

  setup do
    @destination = destinations(:destination_one)
  end

  test 'destinations_search_placeholder uses localized filter keys' do
    I18n.with_locale(:fr) do
      assert_equal 'nom:Paris ville:Lyon', destinations_search_placeholder
    end

    I18n.with_locale(:en) do
      assert_equal 'name:Paris city:Lyon', destinations_search_placeholder
    end
  end

  test 'destinations_list_geocoding helpers expose accuracy and geocoder free text' do
    @destination.geocoding_accuracy = 0.92
    @destination.geocoding_level = :house
    @destination.geocoding_result = { 'free' => '12 rue Example, Paris' }

    assert_equal 92, destinations_list_geocoding_accuracy_percent(@destination)
    assert_equal 'fa-store', destinations_list_geocoding_level_icon_class(@destination)
    assert_equal '12 rue Example, Paris', destinations_list_geocoding_result_free(@destination)
  end

  test 'destinations_list_visit_tags_labels returns unique sorted visit category labels' do
    assert_equal ['tag1'], destinations_list_visit_tags_labels(@destination)

    visit = Visit.new(
      destination: @destination,
      ref: 'visit-tags-col',
      duration: '00:05:00',
      time_window_start_1: '10:00:00',
      time_window_end_1: '11:00:00'
    )
    visit.tags = [tags(:tag_two), tags(:tag_one)]
    visit.save!

    assert_equal %w[tag1 tag2], destinations_list_visit_tags_labels(@destination.reload)
    assert_equal 2, destinations_list_visit_tags(@destination).size
  end
end
