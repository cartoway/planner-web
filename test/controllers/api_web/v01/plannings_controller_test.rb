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
    assert_response :not_found
  end

  test 'should sign in with api_key' do
    sign_out :user
    get :edit, params: { id: @planning, api_key: 'testkey1' }
    assert_response :success
    assert_not_nil assigns(:planning)
  end

  test 'should sign in with Api-Key header' do
    sign_out :user
    request.headers['Api-Key'] = 'testkey1'
    get :edit, params: { id: @planning }
    assert_response :success
    assert_not_nil assigns(:planning)
  end

  test 'should sign in with embed_token query' do
    sign_out :user
    token = ApiWebEmbedToken.issue!(users(:user_one), origin: 'https://erp.example.com')[:token]
    get :edit, params: { id: @planning, embed_token: token }
    assert_response :success
    assert_not_nil assigns(:planning)
    assert_equal "frame-ancestors 'self' https://erp.example.com", response.headers['Content-Security-Policy']
    assert_not response.headers.key?('X-Frame-Options')
  end

  test 'should sign in with embed Bearer token' do
    sign_out :user
    token = ApiWebEmbedToken.issue!(users(:user_one))[:token]
    request.headers['Authorization'] = "Bearer #{token}"
    get :edit, params: { id: @planning }
    assert_response :success
    assert_nil response.headers['Content-Security-Policy']
  end

  test 'should reject an expired embed_token' do
    sign_out :user
    token = ApiWebEmbedToken.issue!(users(:user_one), expires_in: 60)[:token]
    travel 2.minutes do
      get :edit, params: { id: @planning, embed_token: token }
      assert_redirected_to new_user_session_path
    end
  end

  test 'should get edit' do
    without_loading Stop do
      get :edit, params: { id: @planning }
      assert_response :success
      assert_valid response
      assert_match(/id=["']planning-scroll["']/, response.body)
    end
  end

  test 'should print' do
    get :print, params: { id: @planning }
    assert_response :success
  end
end
