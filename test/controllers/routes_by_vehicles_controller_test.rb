require 'test_helper'

require 'rexml/document'

class RoutesByVehiclesControllerTest < ActionController::TestCase
  include REXML

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @vehicle = vehicles(:vehicle_one)
    sign_in users(:user_one)
  end

  test 'user can only view routes from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :show, @vehicle
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :show, @vehicle

    get :show, params: { vehicle_id: vehicles(:vehicle_two).id }
    assert_response :redirect
  end

  test 'should show routes by vehicle' do
    get :show, params: { vehicle_id: @vehicle.id }
    assert_response :success
    assert_valid response
  end

  test 'should show routes by vehicle as json' do
    get :show, params: { vehicle_id: @vehicle.id, format: :json }
    assert_response :success
    assert_valid response
  end
end
