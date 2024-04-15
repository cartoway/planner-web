require 'test_helper'

class VehicleUsagesControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    sign_in users(:user_one)
    assert_valid response
  end

  test 'user can only view vehicle_usages from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :edit, @vehicle_usage
    assert ability.can? :update, @vehicle_usage
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @vehicle_usage

    get :edit, id: vehicle_usages(:vehicle_usage_two_one)
    assert_response :not_found
  end

  test 'should get edit' do
    get :edit, id: @vehicle_usage
    assert_response :success
    assert_valid response
  end

  test 'should update vehicle_usage' do
    patch :update, id: @vehicle_usage, vehicle_usage: {vehicle: {capacities: {'1' => 123, '2' => 456}, color: @vehicle_usage.vehicle.color, consumption: @vehicle_usage.vehicle.consumption, emission: @vehicle_usage.vehicle.emission, name: @vehicle_usage.vehicle.name, max_distance: 200, router_options: {motorway: 'true', trailers: 2, weight: 10, width: '3,55', hazardous_goods: 'gas', low_emission_zone: 'false'}}, time_window_start: @vehicle_usage.time_window_start}
    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    assert_equal [123, 456], @vehicle_usage.vehicle.reload.capacities.values
    # FIXME: replace each assertion by one which checks if hash is included in another
    assert @vehicle_usage.vehicle.router_options['weight'] = '10'
    assert @vehicle_usage.vehicle.router_options['motorway'] = 'true'
    assert @vehicle_usage.vehicle.router_options['low_emission_zone'] = 'false'
    assert @vehicle_usage.vehicle.router_options['trailers'] = '2'
    assert @vehicle_usage.vehicle.router_options['width'] = '3.55'
    assert @vehicle_usage.vehicle.router_options['hazardous_goods'] = 'gas'
    assert @vehicle_usage.vehicle['max_distance'] = '200'
  end

  test 'should store max_distance as an integer by converting miles or kms into meters' do
    [{ prefered_unit: 'mi', value: 59 }, { prefered_unit: 'km', value: 94.951 }].each do |obj|
      users(:user_one).update(prefered_unit: obj[:prefered_unit])
      sign_out users(:user_one)
      sign_in users(:user_one)
      patch :update, id: @vehicle_usage, vehicle_usage: { vehicle: {max_distance: obj[:value] || nil} }
      assert_equal 94951, @vehicle_usage.vehicle.max_distance
    end
  end

  test 'should store max_ride_distance as an integer by converting miles or kms into meters' do
    [{ prefered_unit: 'mi', value: 59 }, { prefered_unit: 'km', value: 94.951 }].each do |obj|
      users(:user_one).update(prefered_unit: obj[:prefered_unit])
      sign_out users(:user_one)
      sign_in users(:user_one)
      patch :update, id: @vehicle_usage, vehicle_usage: { vehicle: {max_ride_distance: obj[:value] || nil} }
      assert_equal 94951, @vehicle_usage.vehicle.max_ride_distance
    end
  end

  test 'should not update max_distance if null or not given' do
    [{ max_distance: nil }, {}].each do |max_distance_param|
      @vehicle_usage.vehicle.update(max_distance_param)
      patch :update, id: @vehicle_usage, vehicle_usage: { vehicle: max_distance_param }
      assert_nil @vehicle_usage.vehicle.max_distance
    end
  end

  test 'should not update max ride distance_time if null or not given' do
    [{ max_ride_distance: nil, max_ride_duration: nil }, {}].each do |max_ride_param|
      @vehicle_usage.vehicle.update(max_ride_param)
      patch :update, id: @vehicle_usage, vehicle_usage: { vehicle: max_ride_param }
      assert_nil @vehicle_usage.vehicle.max_ride_distance
      assert_nil @vehicle_usage.vehicle.max_ride_duration
    end
  end

  test 'should update vehicle_usage with default time_window_end' do
    patch :update, id: @vehicle_usage, vehicle_usage: { time_window_start: '07:00', time_window_end_day: '1' }
    assert_equal @vehicle_usage.reload.time_window_start, 7 * 3_600
    assert_equal @vehicle_usage.reload.time_window_end, @vehicle_usage.default_time_window_end
  end

  test 'should update vehicle usage and vehicle with tags' do
    patch :update, id: @vehicle_usage, vehicle_usage: { tag_ids: [tags(:tag_one).id], vehicle: {tag_ids: [tags(:tag_two).id]} }
    assert_equal @vehicle_usage.reload.tags.size, 1
    assert_equal @vehicle_usage.vehicle.reload.tags.size, 1
  end

  test 'should update vehicle_usage with time exceeding one day' do
    patch :update, id: @vehicle_usage, vehicle_usage: { time_window_start: '20:00', time_window_end: '08:00', time_window_end_day: '1', rest_start: '22:00', rest_stop: '23:00' }
    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    @vehicle_usage.reload
    assert_equal @vehicle_usage.time_window_end, 32 * 3_600

    patch :update, id: @vehicle_usage, vehicle_usage: { time_window_start: '08:00', time_window_start_day: '1', time_window_end: '12:00', time_window_end_day: '1', rest_start: '10:00', rest_start_day: '1', rest_stop: '11:00', rest_stop_day: '1', rest_duration: '01:00' }
    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    @vehicle_usage.reload
    assert_equal @vehicle_usage.time_window_start, 32 * 3_600
    assert_equal @vehicle_usage.time_window_end, 36 * 3_600
    assert_equal @vehicle_usage.rest_start, 34 * 3_600
    assert_equal @vehicle_usage.rest_stop, 35 * 3_600
  end

  test 'should not update vehicle_usage' do
    patch :update, id: @vehicle_usage, vehicle_usage: { vehicle: {name: ''} }

    assert_template :edit
    vehicle_usage = assigns(:vehicle_usage)
    assert vehicle_usage.errors.any?
    assert_valid response
  end

  test 'should disable vehicle usage' do
    patch :toggle, id: @vehicle_usage.id
    assert !@vehicle_usage.reload.active
    assert_redirected_to vehicle_usage_sets_path + "#collapseUsageSet#{vehicle_usage_sets(:vehicle_usage_set_one).id}"
  end

  test 'should set phone number' do
    phone_number = '0578986548'
    patch :update, id: @vehicle_usage, vehicle_usage: { vehicle: { phone_number: phone_number } }
    assert @vehicle_usage.vehicle.reload.phone_number == phone_number
  end

end
