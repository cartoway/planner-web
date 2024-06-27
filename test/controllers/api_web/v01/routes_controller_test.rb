require 'test_helper'

class ApiWeb::V01::RoutesControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @route = routes(:route_one_one)
    sign_in users(:user_one)
  end

  test 'user can only view routes from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :index, @route
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :index, @route

    assert @controller.can?(:index, @route.planning)
    assert @controller.cannot?(:index, plannings(:planning_three))

    get :index, params: { planning_id: plannings(:planning_three) }
    assert_response :redirect
    assert_nil assigns(:routes)
  end

  test 'should get routes' do
    get :index, params: { planning_id: @route.planning_id }
    assert_response :success
    assert_not_nil assigns(:routes)
    assert_valid response
  end

  test 'should print' do
    get :print, params: { planning_id: @route.planning_id, id: @route.id }
    assert_response :success
  end
end
