require 'test_helper'

class IndexControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_valid response
  end

  test 'should raise a warning flash error' do
    user = users(:user_one)
    user.customer.update! end_subscription: Time.now + 15.days
    sign_in user
    get :index
    assert_not_nil flash.now[:warning]
  end
end
