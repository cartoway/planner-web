require 'test_helper'

class ApiWeb::V01::StoresControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @store = stores(:store_one)
    sign_in users(:user_one)
  end

  test 'user can only view stores from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @store
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @store

    assert @controller.can?(:edit_position, @store)
    assert @controller.cannot?(:edit_position, stores(:store_two))

    get :index, params: { ids: stores(:store_two).id }
    assert_equal 0, assigns(:stores).count
    get :edit_position, params: { id: stores(:store_two) }
    assert_response :redirect
  end

  test 'should sign in with api_key' do
    sign_out users(:user_one)
    get :index, params: { api_key: 'testkey1' }
    assert_response :success
    assert_not_nil assigns(:customer)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_nil assigns(:stores)
    assert_valid response
  end

  test 'should get index with ref' do
    get :index, params: { 'ids' => 'ref:b' }
    assert_response :success
    assert_not_nil assigns(:stores)
    assert_valid response
  end

  test 'should get one' do
    get :show, params: { id: @store, format: :json }
    assert_response :success
    assert_valid response
  end

  test 'should get edit position' do
    get :edit_position, params: { id: @store }
    assert_response :success
    assert_valid response
  end

  test 'should update position' do
    patch :update_position, params: { id: @store, store: { lat: 6, lng: 6 } }
    assert_redirected_to api_web_v01_edit_position_store_path(assigns(:store))
  end
end
