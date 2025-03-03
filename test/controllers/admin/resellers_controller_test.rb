require 'test_helper'

class Admin::ResellersControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_admin)
  end

  test 'should get edit' do
    [VonageService, SmsPartnerService].each do |service_class|
      service_class.any_instance.stubs(:balance).returns(42.0)
    end

    Rails.application.config.url_shortener.stubs(:available?).returns(false)

    get :edit, params: { id: @reseller }
    assert_response :success
    assert_valid response
  end

  test 'should update reseller' do
    patch :update, params: { id: @reseller, reseller: { name: @reseller&.name }}
    assert_redirected_to edit_admin_reseller_path(@reseller)
  end
end
