require 'test_helper'

class ApiWeb::V01::DestinationsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @destination = destinations(:destination_one)
    sign_in users(:user_one)
  end

  test 'user can only view destinations from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @destination
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @destination

    assert @controller.can?(:edit_position, @destination)
    assert @controller.cannot?(:edit_position, destinations(:destination_four))

    get :index, params: { ids: destinations(:destination_four).id }
    assert_equal 0, assigns(:destinations).count
    get :edit_position, params: { id: destinations(:destination_four) }
    assert_response :redirect
  end

  test 'should sign in with api_key' do
    sign_out users(:user_one)
    get :index, params: { api_key: 'testkey1' }
    assert_response :success
    assert_not_nil assigns(:customer)
  end

  test 'should get index in html' do
    get :index, params: { format: :html }
    assert_response :success
    assert_nil assigns(:destinations)
    assert_valid response
  end

  test 'should get index in json' do
    get :index, params: { format: :json }
    assert_response :success
    assert_valid response
  end

  test 'should get index by ids in html' do
    get :index, params: { ids: [destinations(:destination_one).id, destinations(:destination_two).id].join(',') }
    assert_response :success
    assert_equal 2, assigns(:destinations).count
    assert_valid response
  end

  test 'should get index by ids in json' do
    get :index, params: { ids: [destinations(:destination_one).id, destinations(:destination_two).id].join(','), format: :json }
    assert_response :success
    assert_equal 2, assigns(:destinations).count
    assert_valid response
  end

  test 'should get index with ref' do
    get :index, params: { 'ids' => 'ref:a' }
    assert_response :success
    assert_equal 1, assigns(:destinations).count
    assert_valid response
  end

  test 'should get index with store_ids' do
    get :index, params: { 'store_ids' => "#{stores(:store_one).id},#{stores(:store_two).id}" }
    assert_response :success
    assert assigns(:stores).present?
    assert_valid response
  end

  test 'should get edit position' do
    get :edit_position, params: { id: @destination }
    assert_response :success
    assert_valid response
  end

  test 'should update position' do
    patch :update_position, params: { id: @destination, destination: { lat: 6, lng: 6 }}
    assert_redirected_to api_web_v01_edit_position_destination_path(assigns(:destination))
  end

  test 'api-web should not have X-Frame-Options' do
    get :index
    assert_not response.headers.key?('X-Frame-Options')
  end
end
