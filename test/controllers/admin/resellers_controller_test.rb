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

  test 'should get edit when messaging balance fetch fails' do
    VonageService.any_instance.stubs(:balance).returns(42.0)
    SmsPartnerService.any_instance.stubs(:balance).raises(OpenSSL::SSL::SSLError.new('certificate verify failed'))

    Rails.application.config.url_shortener.stubs(:available?).returns(false)

    get :edit, params: { id: @reseller }
    assert_response :success
    assert_valid response
  end

  test 'should update reseller' do
    patch :update, params: { id: @reseller, reseller: { name: @reseller&.name }}
    assert_redirected_to edit_admin_reseller_path(@reseller)
  end

  test 'should update reseller default_role_id' do
    return unless Role.column_names.include?('operations')

    role = Role.create!(
      reseller: @reseller,
      name: 'Pick default',
      ref: 'pick_default',
      operations: Preferences::Catalog.baseline_role_operations_json,
      forms: Preferences::Catalog.baseline_role_forms_json
    )

    patch :update, params: { id: @reseller, reseller: { name: @reseller.name, default_role_id: role.id } }
    assert_redirected_to edit_admin_reseller_path(@reseller)
    assert_equal role.id, @reseller.reload.default_role_id
  end

  test 'should update reseller default profile and router' do
    profile = profiles(:profile_one)
    router = routers(:router_one)

    patch :update, params: {
      id: @reseller,
      reseller: {
        name: @reseller.name,
        default_profile_id: profile.id,
        default_router_id: router.id
      }
    }
    assert_redirected_to edit_admin_reseller_path(@reseller)
    @reseller.reload
    assert_equal profile.id, @reseller.default_profile_id
    assert_equal router.id, @reseller.default_router_id
  end

  test 'should update reseller default profile and router from combined select' do
    profile = profiles(:profile_one)
    router = routers(:router_one)

    patch :update, params: {
      id: @reseller,
      reseller: {
        name: @reseller.name,
        default_profile_router: "#{profile.id}_#{router.id}_time"
      }
    }
    assert_redirected_to edit_admin_reseller_path(@reseller)
    @reseller.reload
    assert_equal profile.id, @reseller.default_profile_id
    assert_equal router.id, @reseller.default_router_id
  end
end
