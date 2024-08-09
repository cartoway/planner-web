require 'test_helper'

class ApiWeb::V01::StopsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @stop = stops(:stop_one_one)
    sign_in users(:user_one)
  end

  test 'should get one' do
    get :show, params: { id: @stop, format: :json }
    assert_response :success
    assert_valid response
  end
end
