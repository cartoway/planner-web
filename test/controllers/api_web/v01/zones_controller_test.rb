require 'test_helper'

class ApiWeb::V01::ZonesControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @zone = zones(:zone_one)
    sign_in users(:user_one)
  end

  test 'user can only view zones from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :index, @zone
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :index, @zone

    assert @controller.can?(:index, @zone.zoning)
    assert @controller.cannot?(:index, zonings(:zoning_three))

    get :index, params: { zoning_id: zonings(:zoning_three).id }
    assert_response :redirect
    assert_nil assigns(:zones)
  end

  test 'should sign in with api_key' do
    sign_out users(:user_one)
    get :index, params: { api_key: 'testkey1', zoning_id: @zone.zoning_id }
    assert_response :success
    assert_not_nil assigns(:customer)
  end

  test 'should get zones' do
    get :index, params: { zoning_id: @zone.zoning_id, destinations: true, planning_id: plannings(:planning_one).id }
    assert_response :success
    assert_not_nil assigns(:zones)
    assert_not_nil assigns(:destinations)
    assert_equal vehicle_usage_sets(:vehicle_usage_set_one).id, assigns(:vehicle_usage_set).id
    assert_valid response

    get :index, params: { zoning_id: @zone.zoning_id, destination_ids: destinations(:destination_one), vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_one).id }
    assert_response :success
    assert_not_nil assigns(:zones)
    assert_equal 1, assigns(:destinations).size
    assert_equal vehicle_usage_sets(:vehicle_usage_set_one).id, assigns(:vehicle_usage_set).id
    assert_valid response
  end
end
