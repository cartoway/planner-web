require 'test_helper'

class Admin::UsersControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @user = users(:user_one)
    sign_in users(:user_admin)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:users)
    assert_valid response
  end

  test 'index shows role icon with role name as title when user has a role' do
    return unless Role.column_names.include?('icon')

    role = Role.create!(reseller: @reseller, name: 'Liste rôle test', icon: 'fa-star', color: '#336699')
    @user.update!(role_id: role.id)

    get :index
    assert_response :success
    assert_match(/title="Liste rôle test"/, @response.body)
    assert_includes @response.body, 'fa-star'
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

  test 'create persists role_id when role belongs to same reseller as customer' do
    role = Role.create!(reseller: @reseller, name: 'Label role')

    assert_difference('User.count', 1) do
      post :create, params: {
        user: {
          customer_id: customers(:customer_one).id,
          email: 'with-role@example.com',
          role_id: role.id
        }
      }
    end

    assert_redirected_to admin_users_path
    created = User.find_by!(email: 'with-role@example.com')
    assert_equal role.id, created.reload.role_id
  end

  test 'create does not persist user when role belongs to another reseller' do
    other_reseller = resellers(:reseller_two)
    role = Role.create!(reseller: other_reseller, name: 'Other reseller role')

    assert_no_difference('User.count') do
      post :create, params: {
        user: {
          customer_id: customers(:customer_one).id,
          email: 'wrong-role-reseller@example.com',
          role_id: role.id
        }
      }
    end

    assert_template :new
    assert assigns(:user).errors[:role_id].any?
  end

  test 'create redirect uses params url when present' do
    assert_difference('User.count') do
      post :create, params: {
        user: { customer_id: customers(:customer_one).id, email: 'override-url@example.com' },
        url: admin_users_path
      }
    end
    assert_redirected_to admin_users_path
  end

  test 'update redirect uses params url when present (e.g. customer edit)' do
    return_url = edit_customer_path(customers(:customer_one), anchor: 'users')
    patch :update, params: { id: @user, url: return_url, user: { email: @user.email } }
    assert_redirected_to return_url
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
    patch :update, params: { id: @user, user: { email: 'other@email.example' } }
    assert_redirected_to admin_users_path
    assert_equal 'other@email.example', @user.reload.email
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

  test 'destroy redirects to url when present (e.g. customer edit users tab)' do
    customer = customers(:customer_one)
    return_url = edit_customer_path(customer, anchor: 'users')
    assert_difference('User.count', -1) do
      delete :destroy, params: { id: @user, url: return_url }
    end
    assert_redirected_to return_url
  end

  test 'should destroy multiple user' do
    assert_difference('User.count', -2) do
      delete :destroy_multiple, params: { users: { users(:user_one).id => 1, users(:user_two).id => 1 } }
    end
    assert_redirected_to admin_users_path
  end
end
