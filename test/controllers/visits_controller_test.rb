require 'test_helper'

class VisitsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @visit = visits(:visit_one)
    sign_in users(:user_one)
  end

  test 'should get one' do
    get :show, id: @visit, format: :json
    assert_response :success
    assert_valid response
  end
end
