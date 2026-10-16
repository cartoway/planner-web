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

  test 'destinations_list_card_address_line composes active address columns' do
    @destination.assign_attributes(street: '12 rue des Lilas', postalcode: '33200', city: 'Bordeaux')

    assert_equal '12 rue des Lilas, 33200 Bordeaux',
                 destinations_list_card_address_line(@destination, %w[street postalcode city])
    assert_equal '12 rue des Lilas',
                 destinations_list_card_address_line(@destination, %w[street])
    assert_equal '33200 Bordeaux',
                 destinations_list_card_address_line(@destination, %w[postalcode city])
    assert_nil destinations_list_card_address_line(@destination, %w[ref tags])
    assert_equal %w[tags], destinations_list_card_meta_columns(%w[name street ref geocoding tags])
  end

  test 'destinations_list_card_field_present? is false for blank values' do
    @destination.assign_attributes(comment: nil, phone_number: nil, ref: 'b')
    assert destinations_list_card_field_present?(@destination, 'ref')
    assert_not destinations_list_card_field_present?(@destination, 'comment')
    assert_not destinations_list_card_field_present?(@destination, 'phone_number')
  end

  test 'destination_form_address_geocodable? is true when street postalcode or city is present' do
    @destination.assign_attributes(street: nil, postalcode: nil, city: nil)
    assert_not destination_form_address_geocodable?(@destination)

    @destination.city = 'Bordeaux'
    assert destination_form_address_geocodable?(@destination)
  end

  test 'destination_form_address_fingerprint normalizes address fields' do
    fingerprint = destination_form_address_fingerprint(
      street: '  Rue des Lilas ',
      postalcode: '33200',
      city: 'Bordeau',
      state: '',
      country: 'France'
    )
    assert_equal 'rue des lilas|33200|bordeau||france', fingerprint
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

  test 'destinations_list_sort_header wraps label for ellipsis' do
    @customer = customers(:customer_one)
    html = destinations_list_sort_header('name', 'Nom', nil)
    assert_includes html, 'destinations-list-header-label'
    assert_includes html, 'destinations-list-sort-link'
  end
end
