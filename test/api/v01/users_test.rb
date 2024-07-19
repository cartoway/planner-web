require 'test_helper'

class V01::UsersTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @user = users(:user_two)
  end

  def api(part = nil)
    part = part ? '/' + part.to_s : ''
    "/api/0.1/users#{part}.json?api_key=testkey1"
  end

  def api_admin(part = nil, params = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/users#{part}.json?api_key=adminkey&" + params.collect { |key, value| "#{key}=#{URI::DEFAULT_PARSER.escape(value)}" } .join("&")
  end

  test 'should return users' do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @user.customer.users.size, JSON.parse(last_response.body).size
  end

  test 'should return users from admin key' do
    get api_admin(nil)
    assert last_response.ok?, last_response.body
    assert_equal 4, JSON.parse(last_response.body).size

    get api_admin(nil, {email: @user.email})
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
  end

  test 'should return a user' do
    get api('ref:' + @user.ref)
    assert last_response.ok?, last_response.body
    assert_equal @user.email, JSON.parse(last_response.body)['email']
  end

  test 'should not return a user' do
    get api('ref:' + users(:user_three).ref)
    assert_equal 404, last_response.status, 'Bad response: ' + last_response.body
  end

  test 'should create a user' do
    assert_difference('User.count', 1) do
      # use a new hash here instead of @user.attributes to be able to send password
      post api_admin(), {ref: 'u', email: 'new@plop.com', password: 'password', customer_id: @user.customer_id, layer_id: @user.layer_id, url_click2call: '+77.78.988'}
      assert last_response.created?, last_response.body
      assert_equal 'new@plop.com', JSON.parse(last_response.body)['email']

      get api_admin('ref:u')
      assert last_response.ok?, last_response.body
      assert_equal 'new@plop.com', JSON.parse(last_response.body)['email']
    end
  end

  test 'should not create a user' do
    assert_no_difference('User.count') do
      post api_admin(), {email: 'new@plop.com', password: 'password', customer_id: customers(:customer_two).id, layer_id: @user.layer_id}
      assert_equal 404, last_response.status, 'Bad response: ' + last_response.body
    end
  end

  test 'should update a user' do
    @user.email = 'user@example.com'
    put api_admin('ref:' + @user.ref), @user.attributes
    assert last_response.ok?, last_response.body
    get api_admin(@user.id)
    assert last_response.ok?, last_response.body
    assert_equal @user.reload.email, JSON.parse(last_response.body)['email']
  end

  test 'should not update a user' do
    user = users(:user_three)
    email_reference = 'user@example.com'
    user.email = email_reference
    put api_admin('ref:' + user.ref), user.attributes
    assert last_response.ok?, last_response.body
    get api_admin(@user.id)
    assert last_response.ok?, last_response.body
    assert user.reload.email != email_reference
  end

  test 'should return 402 error' do
    part = users(:user_two).ref
    users(:user_two).customer.update! end_subscription: (Time.now - 30.days)
    part = part ? '/' + part.to_s : ''
    get "/api/0.1/users#{part}.json?api_key=testkey1"
    assert_equal 402, last_response.status
  end

  test 'should destroy a user' do
    assert_difference('User.count', -1) do
      delete api_admin('ref:' + @user.ref)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should not destroy a user' do
    assert_no_difference('User.count') do
      delete api_admin('ref:' + users(:user_three).ref)
      assert_equal 500, last_response.status, 'Bad response: ' + last_response.body
    end
  end

  test 'should destroy multiple users' do
    assert_difference('User.count', -2) do
      delete api_admin + "&ids=#{users(:user_one).id},ref:#{users(:user_two).ref}"
      assert_equal 204, last_response.status, last_response.body
    end
  end
end
