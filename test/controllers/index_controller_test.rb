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

  test 'unsupported browser page shows detected browser name and version' do
    @request.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Cursor/3.9.16 Chrome/144.0.7559.236 Electron/40.10.3 Safari/537.36'

    get :unsupported_browser, params: { browser: 'modern' }

    assert_response :success
    assert_includes response.body, 'Electron'
    assert_includes response.body, '40.10.3'
  end

  test 'should raise a warning flash error' do
    user = users(:user_one)
    user.customer.update! end_subscription: Time.now + 15.days
    sign_in user
    get :index
    assert_not_nil flash.now[:warning]
  end

  test 'home dashboard hides planning dashboard link when planning_dashboard operation is not visible' do
    return unless Role.column_names.include?('operations')

    @reseller.update!(planning_dashboard_url: 'https://analytics.example.com?p_id={P_ID}')
    user = users(:user_one)
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['planning']['segment_controls']['planning_dashboard'] = { 'visible' => false, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "no-home-planning-dashboard-#{SecureRandom.hex(4)}",
      operations: ops,
      forms: Preferences::Catalog.default_forms
    )
    user.update!(role_id: role.id)
    sign_in user

    get :index
    assert_response :success
    assert_not_includes response.body, 'analytics.example.com'
  ensure
    user.update!(role_id: nil)
    role&.destroy
    @reseller.update!(planning_dashboard_url: nil)
    sign_in users(:user_one)
  end
end
