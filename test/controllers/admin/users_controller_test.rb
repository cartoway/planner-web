require 'test_helper'

class Admin::UsersControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @controller = Admin::UsersController.new
    @user = users(:user_one)
    sign_in users(:user_admin)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:users)
    assert_valid response
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create user' do
    assert_difference('User.count') do
      post :create, params: { user: { customer_id: customers(:customer_one).id, email: 'ty@io.com' } }
    end
    assert_redirected_to admin_users_path
  end

  test 'should not create user' do
    assert_difference('User.count', 0) do
      post :create, params: { user: { customer_id: customers(:customer_one).id, email: '' } }
    end
    assert_template :new
    assert assigns(:user).errors.messages[:email].any?
    assert_valid response
  end

  test 'should get edit' do
    get :edit, params: { id: @user }
    assert_response :success
    assert_valid response
  end

  test 'should update user' do
    patch :update, params: { id: @user, user: { email: 'other email' } }
    assert_response :success
    assert_valid response
  end

  test 'should not update user' do
    patch :update, params: { id: @user, user: { email: '' } }
    assert_template :edit
    assert assigns(:user).errors.messages[:email].any?
    assert_valid response
  end

  test 'should destroy user' do
    assert_difference('User.count', -1) do
      delete :destroy, params: { id: @user }
    end
    assert_redirected_to admin_users_path
  end

  test 'should destroy multiple user' do
    assert_difference('User.count', -2) do
      delete :destroy_multiple, params: { users: { users(:user_one).id => 1, users(:user_two).id => 1 } }
    end
    assert_redirected_to admin_users_path
  end
end
