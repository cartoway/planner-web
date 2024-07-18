require 'test_helper'

class VehicleUsageSetsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    sign_in users(:user_one)
    assert_valid response
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect { |i| [1000, 60, '_ibE_seK_seK_seK'] } }) do
      yield
    end
  end

  test 'user can only view vehicle_usage_sets from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :edit, @vehicle_usage_set
    assert ability.can? :update, @vehicle_usage_set
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @vehicle_usage_set

    get :edit, params: { id: vehicle_usage_sets(:vehicle_usage_set_two) }
    assert_response :not_found
  end

  test 'should get index vehicle_usage_set' do
    get :index
    assert_response :success
    assert_not_nil assigns(:vehicle_usage_sets)
    assert_valid response
  end

  test 'should get new vehicle_usage_set' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count') do
      assert_difference('VehicleUsage.count', customers(:customer_one).vehicles.length) do
        post :create, params: { vehicle_usage_set: { name: @vehicle_usage_set.name } }
      end
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should create vehicle_usage_set with time exceeding one day' do
    post :create, params: { vehicle_usage_set: { name: 'toto', time_window_start: '20:00', time_window_end: '08:00', time_window_end_day: '1' } }
    assert_equal VehicleUsageSet.last.time_window_start, 20 * 3_600
    assert_equal VehicleUsageSet.last.time_window_end, 32 * 3_600
  end

  test 'should create vehicle_usage_set with default time_window_end' do
    post :create, params: { vehicle_usage_set: { name: 'toto', time_window_start: '16:00', time_window_end_day: '1' } }
    assert VehicleUsageSet.last.time_window_start, 16 * 3_600
    assert VehicleUsageSet.last.time_window_end, 18 * 3_600
  end

  test 'should not create vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', 0) do
      post :create, params: { vehicle_usage_set: { name: '' } }
    end

    assert_template :new
    vehicle_usage_set = assigns(:vehicle_usage_set)
    assert vehicle_usage_set.errors.any?
    assert_valid response
  end

  test 'should get edit vehicle_usage_set' do
    get :edit, params: { id: @vehicle_usage_set }
    assert_response :success
    assert_valid response
  end

  test 'should update vehicle_usage_set' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: 'toto', time_window_start: @vehicle_usage_set.time_window_start } }
    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should update vehicle_usage_set with time exceeding one day' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: 'toto', time_window_start: '20:00', time_window_end: '08:00', time_window_end_day: '1' } }
    @vehicle_usage_set.reload
    assert_equal @vehicle_usage_set.time_window_start, 20 * 3_600
    assert_equal @vehicle_usage_set.time_window_end, 32 * 3_600

    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: 'toto', time_window_start: '08:00', time_window_start_day: '1', time_window_end: '12:00', time_window_end_day: '1', rest_start: '10:00', rest_start_day: '1', rest_stop: '11:00', rest_stop_day: '1', rest_duration: '01:00' } }
    @vehicle_usage_set.reload
    assert_equal @vehicle_usage_set.time_window_start, 32 * 3_600
    assert_equal @vehicle_usage_set.time_window_end, 36 * 3_600
    assert_equal @vehicle_usage_set.rest_start, 34 * 3_600
    assert_equal @vehicle_usage_set.rest_stop, 35 * 3_600
  end

  test 'should not update vehicle_usage_set' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: '' } }

    assert_template :edit
    vehicle_usage_set = assigns(:vehicle_usage_set)
    assert vehicle_usage_set.errors.any?
    assert_valid response
  end

  test 'should destroy vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', -1) do
      delete :destroy, params: { id: @vehicle_usage_set }
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should disable/enable multiple vehicles' do
    vehicle_usage_set = @vehicle_usage_set.customer.vehicle_usage_sets.first
    vu_hash = {vehicle_usage_set.id.to_s => {}}
    vehicle_usage_set.vehicle_usages.each{ |vu| vu_hash[vehicle_usage_set.id.to_s][vu.id] = 'on' }

    [{action: 'disable_multiple', result: [false, false]}, {action: 'enable_multiple', result: [true, true]}].each do |obj|
      delete :destroy_multiple, params: { vehicle_usages: vu_hash, id: @vehicle_usage_set, obj[:action] => vehicle_usage_set.id }
      assert_equal obj[:result], VehicleUsage.where(vehicle_usage_set_id: vehicle_usage_set).map(&:active)
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should destroy multiple vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', -1) do
      delete :destroy_multiple, params: { vehicle_usage_sets: { vehicle_usage_sets(:vehicle_usage_set_one).id => 1 } }
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should destroy multiple vehicle_usage_set, 0 item' do
    assert_difference('VehicleUsageSet.count', 0) do
      delete :destroy_multiple
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should duplicate vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count') do
      patch :duplicate, params: { vehicle_usage_set_id: @vehicle_usage_set }
    end

    assert_redirected_to edit_vehicle_usage_set_path(assigns(:vehicle_usage_set))
  end

  test 'should import' do
    get :import
    assert_response :success
    assert_valid response
  end

  test 'should show import template' do
    [:csv, :excel].each { |format|
      get :import_template, params: { format: format }
      assert_response :success
    }
  end

  test 'should export vehicle usage set to csv or excel' do
    [:csv, :excel].each { |format|
      get :show, params: { id: @vehicle_usage_set, format: format }
      assert_response :success
      assert_valid response
      assert_match 'text/csv', response.content_type
    }
  end

  test 'should export vehicle usage set to csv whith custom attributes' do
    get :show, params: { id: @vehicle_usage_set, format: :csv }
    assert_response :success
    assert_valid response
    assert_equal 'text/csv; charset=utf-8', response.content_type

    csv = CSV.new(response.body)
    headers = csv.first
    vehicles = [vehicles(:vehicle_three), vehicles(:vehicle_one)]
    csv.each.with_index{ |line, index|
      vehicle = vehicles(line[1].to_sym)
      ['one', 'two', 'three'].each { |key|
        attr_index = headers.index{ |header| header.include?("[custom_attribute_#{key}]") }
        assert attr_index
        assert_equal vehicle.custom_attributes_typed_hash["custom_attribute_#{key}"].to_s, line[attr_index]
      }
    }
  end

  test 'should upload' do
    file = fixture_file_upload(Rails.root.join('test/fixtures/files/import_vehicle_usage_sets_one.csv'), 'text/csv')

    assert_difference('VehicleUsageSet.count', 1) do
      post :upload_csv, params: { import_csv: { replace_vehicles: true, file: file } }
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should use limitation' do
    customer = @vehicle_usage_set.customer
    customer.max_vehicle_usage_sets = customer.vehicle_usage_sets.size + 1
    customer.save!

    assert_difference('VehicleUsageSet.count', 1) do
      post :create, params: { vehicle_usage_set: {
        name: 'new dest',
      } }
      assert_response :redirect
    end

    assert_difference('VehicleUsageSet.count', 0) do
      assert_difference('VehicleUsage.count', 0) do
        post :create, params: { vehicle_usage_set: {
          name: 'new 2',
        } }
      end
    end
  end
end
