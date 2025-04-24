require 'test_helper'

class DestinationTest < ActiveSupport::TestCase
  test 'should not save' do
    destination = Destination.new
    assert_not destination.save, 'Saved without required fields'
  end

  test 'should save' do
    assert_difference('Stop.count', 1) do
      assert_difference('Destination.count') do
        assert_difference('Order.count', 7 * 2) do
          customer = customers(:customer_one)
          destination = customer.destinations.build(name: 'plop', city: 'Bordeaux', state: 'Midi-Pyrénées')
          destination.visits.build(tags: [tags(:tag_one)])
          assert destination.save!
          assert customer.save!
          destination.reload
          assert !destination.lat.nil?, 'Latitude not built'
        end
      end
    end
  end

  test 'should geocode' do
    destination = destinations(:destination_one)
    lat, lng = destination.lat, destination.lng
    destination.geocode
    assert destination.lat
    assert_not_equal lat, destination.lat
    assert destination.lng
    assert_not_equal lng, destination.lng
  end

  test 'should geocode with error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      destination = destinations(:destination_one)
      assert destination.geocode
      assert 1, destination.warnings.size
    end
  end

  test 'should update_geocode' do
    destination = destinations(:destination_one)
    destination.city = 'Toulouse'
    destination.state = 'Midi-Pyrénées'
    destination.lat = destination.lng = nil
    lat, lng = destination.lat, destination.lng
    destination.save!
    assert destination.lat
    assert_not_equal lat, destination.lat
    assert destination.lng
    assert_not_equal lng, destination.lng
  end

  test 'should update_geocode with error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      destination = destinations(:destination_one)
      destination.city = 'Toulouse'
      destination.state = 'Midi-Pyrénées'
      destination.lat = destination.lng = nil
      assert destination.save!
      assert 1, destination.warnings.size
    end
  end

  test 'should not update_geocode' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise }) do
      destination = destinations(:destination_one)
      destination.street = 'rue'
      destination.lat, destination.lng = 1, 1
      assert destination.save
    end
  end

  test 'should distance' do
    destination = destinations(:destination_one)
    assert_equal 47.72248931834969, destination.distance(destinations(:destination_two))
  end

  test 'should destroy and reindex stops' do
    route = routes(:route_one_one)
    destination = destinations(:destination_one)

    route.touch
    route.save!

    assert destination.visits
    destination.destroy

    route.reload
    route.touch
    route.save!
  end

  test 'set Lat, Lng with comma separator' do
    destination = destinations :destination_one
    lat_french_format = '33,499573'
    lng_french_format = '-112,001210'
    lat = 33.499573
    lng = -112.001210
    assert I18n.locale == :fr
    destination.update! lat: lat_french_format, lng: lng_french_format
    assert destination.lat == lat
    assert destination.lng == lng
    destination.update! lat: lat, lng: lng
    assert destination.lat == lat
    assert destination.lng == lng
  end

  test 'should get visits color and icon' do
    destination = destinations :destination_one
    tag_one = tags :tag_one
    tag_two = tags :tag_two
    destination.tags = []
    destination.visits.each{ |v| v.tags = [] }

    assert_nil destination.visits_color
    assert_nil destination.visits_icon

    destination.tags = [tag_one, tag_two]
    assert_equal tag_one.color, destination.visits_color
    assert_equal tag_two.icon,  destination.visits_icon

    destination.tags = []
    destination.visits[0].tags = [tag_one, tag_two]
    assert_equal tag_one.color, destination.visits_color
    assert_equal tag_two.icon,  destination.visits_icon
  end

  test 'should outdate route after tag changed on update' do
    route = routes(:route_zero_one)
    without_loading Stop, if: -> (obj) { obj.route_id != route.id && obj.route_id != routes(:route_zero_two).id } do
      assert !route.outdated
      destinations(:destination_unaffected_one).update tags: [tags(:tag_one), tags(:tag_two)]
      assert route.reload.outdated
    end
  end

  test 'should outdate route after tag changed on save' do
    route = routes(:route_zero_one)
    assert !route.outdated
    dest = destinations(:destination_unaffected_one)
    dest.tags |= [tags(:tag_one), tags(:tag_two)]
    dest.save!
    assert route.reload.outdated
  end

  test 'should have geocoder version' do
    destination = destinations(:destination_one)

    destination.geocode
    assert destination.geocoder_version
    assert_not_equal nil, destination.geocoder_version
  end

  test 'geocoded_at should not be nil' do
    destination = destinations(:destination_one)

    destination.geocode
    assert destination.geocoded_at
    assert_not_equal nil, destination.geocoded_at
  end

  test 'should set destination duration' do
    destination = destinations(:destination_one)
    destination.duration = '00:30:00'
    assert destination.save!
    assert_equal 1800, destination.default_duration
    assert_equal '00:30:00', destination.default_duration_time_with_seconds
  end

  test 'should use customer destination duration as fallback' do
    customer = customers(:customer_one)
    customer.destination_duration = 3600
    customer.save!

    destination = destinations(:destination_one)
    destination.duration = nil
    assert destination.save!
    assert_equal 3600, destination.default_duration
    assert_equal '01:00:00', destination.default_duration_time_with_seconds
  end
end
