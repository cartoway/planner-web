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

    get :edit, params: { id: vehicle_usages(:vehicle_usage_two_one) }
    assert_response :not_found
  end

  test 'should get edit' do
    get :edit, params: { id: @vehicle_usage }
    assert_response :success
    assert_valid response
    assert_select '.input-group-addon', minimum: 1
    assert_select '#vehicle_usage_rest_type_input .form-check', 0
    assert_select 'input.form-check-input[name=?]', 'vehicle_usage[rest_mode]', 0
    assert_select 'input[type=hidden][name=?][value=window]', 'vehicle_usage[rest_mode]', 1
    assert_select '#vehicle_usage_rest_type_input', text: /#{Regexp.escape(I18n.t('vehicle_usages.form.rest_type.window'))}/
    assert_select '#vehicle_usage_rest_type_input', text: /#{Regexp.escape(I18n.t('vehicle_usages.form.rest_type.locked_to_set'))}/
  end

  test 'edit responds with form_sidebar fragment when requested via Turbo Frame' do
    enable_layout_v2!
    @vehicle_usage.vehicle.update!(router: routers(:router_osrm))
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @vehicle_usage }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#vehicle-usage-form-sidebar', 1
    assert_select 'turbo-frame#form_sidebar .form-submit-bar button[type=submit][form=vehicle-usage-form-sidebar]', 1
    assert_select 'form#vehicle-usage-form-sidebar input[name="v2_sidebar"][value="1"]', 1
    assert_select 'form#vehicle-usage-form-sidebar .input-group-text', minimum: 1
    assert_select 'form#vehicle-usage-form-sidebar .input-group-addon', 0
    assert_select 'form#vehicle-usage-form-sidebar .offset-md-1', minimum: 1
    assert_select '#vehicle_usage_time_window_start_time_window_end_input.fleet-split .input-group', 2
    assert_select 'form#vehicle-usage-form-sidebar[data-controller~="v2--rest-type-fields"]', 1
    assert_select 'form#vehicle-usage-form-sidebar[data-controller~="v2--router-options"]', 1
    assert_select 'form#vehicle-usage-form-sidebar[data-controller~="v2--number-to-percentage"]', 1
    assert_select 'form#vehicle-usage-form-sidebar[data-controller~="v2--vehicle-devices"]', 1
    assert_select 'script[src*="vehicle_usage"]', 0
    assert_select 'form#vehicle-usage-form-sidebar[data-v2--rest-type-fields-prefix-value="vehicle_usage"]', 1
    assert_select 'input#vehicle_usage_vehicle_color[type=color][name="vehicle_usage[vehicle][color]"]', 1
    assert_select 'select[name="vehicle_usage[vehicle][color]"]', 0
    assert_select '#router_options_traffic_input.router-option-disabled', 1
    assert_select 'select[name$="[tag_ids][]"][multiple][data-controller~="v2--tom-select"]', minimum: 1
  end

  test 'edit sidebar store reloads is a tom-select multi-select' do
    enable_layout_v2!
    @vehicle_usage.vehicle.customer.update!(enable_store_stops: true)
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @vehicle_usage }
    assert_response :success
    assert_select 'select#vehicle_usage_store_reload_ids[multiple][data-controller~="v2--tom-select"]', 1
    assert_select 'select#vehicle_usage_store_reload_ids[data-v2--tom-select-simple-value="true"]', 1
  end

  test 'vehicle form should show updated customer router option defaults' do
    customer = @vehicle_usage.vehicle.customer
    @vehicle_usage.vehicle.update!(router_id: nil, router_options: {})
    customer.update!(router_options: customer.router_options.merge('weight' => 42))

    get :edit, params: { id: @vehicle_usage }

    assert_response :success
    assert_includes response.body, I18n.t('customers.form.router_options_default', n: 42)
  end

  test 'should update vehicle_usage' do
    patch :update, params: { id: @vehicle_usage, vehicle_usage: {vehicle: {capacities: {'1' => 123, '2' => 456}, color: @vehicle_usage.vehicle.color, consumption: @vehicle_usage.vehicle.consumption, emission: @vehicle_usage.vehicle.emission, name: @vehicle_usage.vehicle.name, max_distance: 200, router_options: {motorway: 'true', trailers: 2, weight: 10, width: '3,55', hazardous_goods: 'gas', low_emission_zone: 'false'}}, time_window_start: @vehicle_usage.time_window_start}}
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

  test 'v2 update from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    patch :update, params: { id: @vehicle_usage, v2_sidebar: '1', vehicle_usage: { vehicle: { name: @vehicle_usage.vehicle.name } } }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#vehicle-usage-form-sidebar', 0
  end

  test 'should store max_distance as an integer by converting miles or kms into meters' do
    [{ prefered_unit: 'mi', value: 59 }, { prefered_unit: 'km', value: 94.951 }].each do |obj|
      users(:user_one).update(prefered_unit: obj[:prefered_unit])
      sign_out users(:user_one)
      sign_in users(:user_one)
      patch :update, params: { id: @vehicle_usage, vehicle_usage: { vehicle: {max_distance: obj[:value] || nil} }}
      assert_equal 94951, @vehicle_usage.vehicle.max_distance
    end
  end

  test 'should store max_ride_distance as an integer by converting miles or kms into meters' do
    [{ prefered_unit: 'mi', value: 59 }, { prefered_unit: 'km', value: 94.951 }].each do |obj|
      users(:user_one).update(prefered_unit: obj[:prefered_unit])
      sign_out users(:user_one)
      sign_in users(:user_one)
      patch :update, params: { id: @vehicle_usage, vehicle_usage: { vehicle: {max_ride_distance: obj[:value] || nil} }}
      assert_equal 94951, @vehicle_usage.vehicle.max_ride_distance
    end
  end

  test 'should not update max_distance if null or not given' do
    [{ max_distance: nil }, {}].each do |max_distance_param|
      @vehicle_usage.vehicle.update(max_distance_param)
      patch :update, params: { id: @vehicle_usage, vehicle_usage: { id: @vehicle_usage, vehicle: max_distance_param }}
      assert_nil @vehicle_usage.vehicle.max_distance
    end
  end

  test 'should not update max ride distance_time if null or not given' do
    [{ max_ride_distance: nil, max_ride_duration: nil }, {}].each do |max_ride_param|
      @vehicle_usage.vehicle.update(max_ride_param)
      patch :update, params: { id: @vehicle_usage, vehicle_usage: { id: @vehicle_usage, vehicle: max_ride_param }}
      assert_nil @vehicle_usage.vehicle.max_ride_distance
      assert_nil @vehicle_usage.vehicle.max_ride_duration
    end
  end

  test 'should update vehicle_usage with default time_window_end' do
    patch :update, params: { id: @vehicle_usage, vehicle_usage: { time_window_start: '07:00', time_window_end_day: '1' }}
    assert_equal @vehicle_usage.reload.time_window_start, 7 * 3_600
    assert_equal @vehicle_usage.reload.time_window_end, @vehicle_usage.default_time_window_end
  end

  test 'should update vehicle usage and vehicle with tags' do
    patch :update, params: { id: @vehicle_usage, vehicle_usage: { tag_ids: [tags(:tag_one).id], vehicle: {tag_ids: [tags(:tag_two).id]}}}
    assert_equal @vehicle_usage.reload.tags.size, 1
    assert_equal @vehicle_usage.vehicle.reload.tags.size, 1
  end

  test 'should update vehicle_usage with time exceeding one day' do
    patch :update, params: { id: @vehicle_usage, vehicle_usage: { time_window_start: '20:00', time_window_end: '08:00', time_window_end_day: '1', rest_start: '22:00', rest_stop: '23:00' }}
    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    @vehicle_usage.reload
    assert_equal @vehicle_usage.time_window_end, 32 * 3_600

    patch :update, params: { id: @vehicle_usage, vehicle_usage: { time_window_start: '08:00', time_window_start_day: '1', time_window_end: '12:00', time_window_end_day: '1', rest_start: '10:00', rest_start_day: '1', rest_stop: '11:00', rest_stop_day: '1', rest_duration: '01:00' }}
    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    @vehicle_usage.reload
    assert_equal @vehicle_usage.time_window_start, 32 * 3_600
    assert_equal @vehicle_usage.time_window_end, 36 * 3_600
    assert_equal @vehicle_usage.rest_start, 34 * 3_600
    assert_equal @vehicle_usage.rest_stop, 35 * 3_600
  end

  test 'should ignore rest type switch on vehicle_usage' do
    original_start = @vehicle_usage.rest_start

    patch :update, params: { id: @vehicle_usage, vehicle_usage: { rest_mode: 'regulatory', rest_lapse: '06:00' }}

    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    @vehicle_usage.reload
    assert_nil @vehicle_usage.rest_lapse
    assert_equal original_start, @vehicle_usage.rest_start
    assert_not @vehicle_usage.regulatory_rest?
  end

  test 'should update vehicle_usage with regulatory rest lapse' do
    enable_regulatory_rest!(@vehicle_usage, duration: 30.minutes.to_i, lapse: 8.hours.to_i)

    patch :update, params: { id: @vehicle_usage, vehicle_usage: { rest_duration: '00:45', rest_lapse: '06:00' }}
    assert_redirected_to edit_vehicle_usage_path(@vehicle_usage)
    @vehicle_usage.reload
    assert_equal 45.minutes.to_i, @vehicle_usage.rest_duration
    assert_equal 6.hours.to_i, @vehicle_usage.rest_lapse
    assert_nil @vehicle_usage.rest_start
    assert_nil @vehicle_usage.rest_stop
  end

  test 'should not update vehicle_usage' do
    patch :update, params: { id: @vehicle_usage, vehicle_usage: { vehicle: {name: ''} } }

    assert_template :edit
    vehicle_usage = assigns(:vehicle_usage)
    assert vehicle_usage.errors.any?
    assert_valid response
  end

  test 'should disable vehicle usage' do
    patch :toggle, params: { id: @vehicle_usage.id }
    assert !@vehicle_usage.reload.active
    assert_redirected_to vehicle_usage_sets_path + "#collapseUsageSet#{vehicle_usage_sets(:vehicle_usage_set_one).id}"
  end

  test 'should set phone number' do
    phone_number = '0578986548'
    patch :update, params: { id: @vehicle_usage, vehicle_usage: { vehicle: { phone_number: phone_number }}}
    assert @vehicle_usage.vehicle.reload.phone_number == phone_number
  end

  test 'should update vehicle custom attributes' do
    customer = @vehicle_usage.vehicle.customer
    custom_attribute = customer.custom_attributes.for_vehicle.find{ |ca| ca.object_type == 'integer' }
    assert_not_nil custom_attribute

    patch :update, params: {
      id: @vehicle_usage,
      vehicle_usage: {
        vehicle: {
          custom_attributes: {
            custom_attribute.name => '42'
          }
        }
      }
    }

    typed_hash = @vehicle_usage.vehicle.reload.custom_attributes_typed_hash
    assert_equal 42, typed_hash[custom_attribute.name]
  end
end
