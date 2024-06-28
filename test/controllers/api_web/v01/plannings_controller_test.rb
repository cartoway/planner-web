require 'test_helper'

class ApiWeb::V01::PlanningsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @planning = plannings(:planning_one)
    sign_in users(:user_one)
  end

  test 'user can only view plannings from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @planning
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @planning

    assert @controller.can?(:edit, @planning)
    assert @controller.cannot?(:edit, plannings(:planning_three))

    get :edit, params: { id: plannings(:planning_three) }
    assert_response :redirect
  end

  test 'should sign in with api_key' do
    sign_out :user
    get :edit, params: { id: @planning, api_key: 'testkey1' }
    assert_response :success
    assert_not_nil assigns(:planning)
  end

  test 'should get edit' do
    without_loading Stop do
      get :edit, params: { id: @planning }
      assert_response :success
      assert_valid response
    end
  end

  test 'should print' do
    get :print, params: { id: @planning }
    assert_response :success
  end
end
