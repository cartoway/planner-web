require 'test_helper'

class ReportingControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
  end

  test 'should get reporting page if authenticated and have fleet device' do
    sign_in(users(:user_one))

    get :index

    assert_response :success
  end

  test 'index uses v2 when user preference is set' do
    sign_in(users(:user_one))
    enable_layout_v2!
    get :index
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select '[data-controller="v2--reporting-download"]', 1
    assert_select 'input[type=date]#reporting_begin_date', 1
  end

  test 'admin cannot get reporting' do
    sign_in(users(:user_admin))

    get :index

    assert_response 302
  end

  test 'should not get reporting page if not authenticated' do
    get :index

    assert_response 302
  end
end
