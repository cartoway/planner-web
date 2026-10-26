require 'test_helper'

class CustomersControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @customer = customers(:customer_one)
    # Leftover open operations from other tests break duplicate inside transaction_without_selects.
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'user can only edit its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :edit, customers(:customer_one)
    assert ability.can? :update, customers(:customer_one)
    ability = Ability.new(users(:user_three))
    assert ability.cannot? [:manage], customers(:customer_one)
    ability = Ability.new(users(:user_admin))
    assert ability.can? :manage, customers(:customer_one)

    sign_in users(:user_one)
    get :edit, params: { id: customers(:customer_two) }
    assert_response :not_found
  end

  test 'should get edit' do
    sign_in users(:user_one)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_valid response
  end

  test 'admin edit shows suivi section when operations device is enabled' do
    sign_in users(:user_admin)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '#customer_suivi_section:not(.d-none)'
    assert_select '#collapseSuivi'
    assert_select '#customer_enable_proofs'
    assert_select '#customer_enable_vehicle_position'
    assert_select '#customer_history_cron_hour'
    assert_select '#customer_notifications_panel'
    assert_select '#customer_notifications_email_panel'
    assert_select '#customer_notifications_sms_panel'
    assert_select '#customer_enable_email_driver:not([disabled])'
    assert_select '#customer_enable_email_destination:not([disabled])'
    assert_select '#customer_enable_sms_driver'
    assert_select '#customer_enable_sms_destination'
    assert_select '#customer_enable_sms_intransit'
    # ETA gaps are shared by email/SMS — at Notifications level, not inside Email.
    assert_select '#collapseNotifications #customer_delivery_tracking_eta_gap_before', 1
    assert_select '#collapseNotifications #customer_delivery_tracking_eta_gap_after', 1
    assert_select '#collapseNotificationsEmail #customer_delivery_tracking_eta_gap_before', 0
    assert_select '#collapseNotificationsSms #customer_delivery_tracking_eta_gap_before', 0
    assert_select "label[for='customer_enable_proofs']", text: I18n.t('activerecord.attributes.customer.enable_proofs')
  end

  test 'non admin cannot toggle email or sms notification enables' do
    @customer.update!(
      enable_email_destination: true,
      enable_sms_destination: true,
      enable_email_driver: false,
      enable_sms_driver: false,
      enable_sms_intransit: false
    )
    sign_in users(:user_one)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '#customer_enable_email_driver', 0
    assert_select '#customer_enable_email_destination', 0
    assert_select '#customer_enable_sms_driver', 0
    assert_select '#customer_enable_sms_destination', 0
    assert_select '#customer_enable_sms_intransit', 0
    assert_select '#customer_destination_email_template_wrap:not(.d-none)', 1
    assert_select '#customer_sms_template_wrap:not(.d-none)', 1
    assert_select 'textarea#customer_recipient_template', 1
    assert_select 'textarea#customer_sms_template', 1

    patch :update, params: {
      id: @customer.id,
      customer: {
        enable_email_destination: false,
        enable_sms_destination: false,
        enable_email_driver: true,
        enable_sms_driver: true,
        enable_sms_intransit: true
      }
    }
    @customer.reload
    assert @customer.enable_email_destination
    assert @customer.enable_sms_destination
    assert_not @customer.enable_email_driver
    assert_not @customer.enable_sms_driver
    assert_not @customer.enable_sms_intransit
  end

  test 'non admin hides inactive notification sections' do
    @customer.update!(
      enable_email_destination: false,
      enable_email_driver: false,
      enable_sms_destination: false,
      enable_sms_driver: false,
      enable_sms_intransit: false
    )
    sign_in users(:user_one)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '#customer_notifications_panel', 0

    @customer.update!(enable_email_destination: true)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '#customer_notifications_panel', 1
    assert_select '#customer_notifications_email_panel', 1
    assert_select '#customer_notifications_sms_panel', 0

    @customer.update!(enable_email_destination: false, enable_sms_intransit: true)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '#customer_notifications_panel', 1
    assert_select '#customer_notifications_email_panel', 0
    assert_select '#customer_notifications_sms_panel', 1
  end

  test 'admin edit hides suivi section without operations device' do
    @customer.update!(devices: { tomtom: { enable: true, account: 'a', user: 'u', password: 'p' } })
    sign_in users(:user_admin)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '#customer_suivi_section.d-none'
  end

  test 'non admin cannot see or enable deliver demo' do
    @customer.update!(devices: { deliver: { enable: true, demo: false, driver_move: false } })
    sign_in users(:user_one)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select 'input[name="customer[devices][deliver][demo]"]', count: 0

    patch :update, params: {
      id: @customer.id,
      customer: { devices: { deliver: { enable: true, demo: true, driver_move: false } } }
    }
    assert_not ValueToBoolean.value_to_boolean(@customer.reload.devices.dig('deliver', 'demo') || @customer.devices.dig(:deliver, :demo))
  end

  test 'non-admin edit hides last_async_jobs' do
    @customer.update_column(:last_async_jobs, {
      'optimizer' => {
        'id' => 42,
        'type' => 'optimizer',
        'status' => 'succeeded',
        'finished_at' => '2026-09-14T10:00:00Z'
      }
    })

    sign_in users(:user_one)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select '.last-async-jobs', count: 0
  end

  test 'admin customer edit users tab lists role column' do
    sign_in users(:user_admin)
    get :edit, params: { id: @customer }
    assert_response :success
    assert_select 'table#users thead th', { text: I18n.t('customers.edit.role_column'), count: 1 }
  end

  test 'admin customer index dropdown lists every user without cap' do
    sign_in users(:user_admin)
    layer = layers(:layer_one)
    3.times do |i|
      User.create!(
        email: "extra-user-#{i}@example.com",
        customer: @customer,
        layer: layer,
        password: 'dummy_password',
        password_confirmation: 'dummy_password',
        time_zone: 'Hawaii'
      )
    end

    get :index
    assert_response :success

    assert_select "#customerUsersDropdown#{@customer.id} .customer-users-summary__row", count: @customer.users.count
    assert_select "#customerUsersDropdown#{@customer.id} .customer-users-summary__email", text: 'extra-user-0@example.com'
  end

  test 'should update customer' do
    sign_in users(:user_one)
    patch :update, params: { id: @customer, customer: {name: 123, router_dimension: 'distance', router_options: {motorway: 'true', trailers: 2, weight: 10, width: '3,55', hazardous_goods: 'gas', low_emission_zone: 'false'}, optimization_minimal_time: 4, optimization_time: 10}}
    assert_redirected_to [:edit, @customer]
    assert_equal 'distance', @customer.reload.router_dimension
    # FIXME: replace each assertion by one which checks if hash is included in another
    assert @customer.reload.router_options['motorway'] = 'true'
    assert @customer.reload.router_options['low_emission_zone'] = 'false'
    assert @customer.reload.router_options['trailers'] = '2'
    assert @customer.reload.router_options['weight'] = '10'
    assert @customer.reload.router_options['width'] = '3.55'
    assert @customer.reload.router_options['hazardous_goods'] = 'gas'
    assert @customer.reload['optimization_minimal_time'] = 4
    assert @customer.reload['optimization_time'] = 10
  end

  test 'should not destroy vehicles' do
    assert_difference('Vehicle.count', 0) do
      delete :delete_vehicle, params: { id: @customer.id, vehicle_id: vehicles(:vehicle_one).id }
    end
  end

  test 'should delete customer' do
    sign_in users(:user_admin)
    delete :destroy, params: { id: @customer.id }
    assert_redirected_to customers_path
    assert !assigns(:customer).persisted?
  end

  test 'should delete multiple customers' do
    sign_in users(:user_admin)
    delete :destroy_multiple, params: {customers: {@customer.id => 1}}
    assert_redirected_to customers_path
  end

  test 'should disabled max_vehicles field' do
    begin
      Planner::Application.config.manage_vehicles_only_admin = true
      sign_in users(:user_one)
      get :edit, params: { id: @customer.id }
      assert_response :success
      assert_select 'form input' do
        assert_select "[name='customer[max_vehicles]']" do
          assert_select '[disabled=?]', 'disabled'
        end
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = false
    end
  end

  test 'should not disabled max_vehicles field' do
    sign_in users(:user_one)
    get :edit, params: { id: @customer.id }
    assert_response :success
    assert_select 'form input' do
      assert_select "[name='customer[max_vehicles]']" do
        assert_select '[disabled]', false
      end
    end
  end

  test 'should duplicate customer' do
    sign_in users(:user_admin)
    assert_difference('Customer.count', 1) do
      patch :duplicate, params: { id: @customer.id }
    end
  end

  test 'should duplicate customer with error' do
    begin
      orig_validate_during_duplication = Planner::Application.config.validate_during_duplication
      Planner::Application.config.validate_during_duplication = false

      @customer.plannings[1].routes[1].stops[0].index = 666
      @customer.plannings[1].routes[1].stops[0].save!

      sign_in users(:user_admin)
      assert_difference('Customer.count', 1) do
        patch :duplicate, params: { id: @customer.id }
        assert_redirected_to customers_path, response.body.to_s.truncate(500)
      end
    ensure
      Planner::Application.config.validate_during_duplication = orig_validate_during_duplication
    end
  end

  test 'should dump customer for export' do
    sign_in users(:user_admin)

    get :export, params: { id: @customer.id }

    assert_response :success
  end

  test 'should render import action if no file is uploaded on import' do
    sign_in users(:user_admin)

    reseller = users(:user_admin).reseller
    import_role = Role.create_default_permissions_role_for!(reseller)

    post :upload_dump, params: { customer: { profile_id: profiles(:profile_one).id, router_id: routers(:router_one).id, layer_id: layers(:layer_one).id, import_user_role_id: import_role.id }}

    assert_template :import
  end

  test 'import page includes role select for imported users' do
    sign_in users(:user_admin)
    Role.create_default_permissions_role_for!(users(:user_admin).reseller)

    get :import

    assert_response :success
    assert_select "select[name='customer[import_user_role_id]']"
  end

  test 'should require authentication' do
    post :external_callback, params: { id: @customer.id }
    assert_redirected_to root_path

    sign_in users(:user_one)
    post :external_callback, params: { id: @customer.id }, format: :json
    assert_response :forbidden
  end

  test 'should make external callback with planning and route' do
    user = users(:user_one)
    sign_in user

    @customer.update(enable_external_callback: true, external_callback_url: 'https://example.com/{PLANNING_ID}/{ROUTE_ID}/{API_KEY}/{CUSTOMER_ID}')

    planning = @customer.plannings.first
    route = planning.routes[1]

    stub_request(:get, "https://example.com/#{planning.id}/#{route.id}/#{user.api_key}/#{@customer.id}")
      .to_return(status: 200)

    post :external_callback, params: { id: @customer.id, planning_id: planning.id, route_id: route.id }, format: :json
    assert_response :success
    assert_equal 'ok', JSON.parse(response.body)['status']
  end

  test 'should make external callback with multiple plannings' do
    user = users(:user_one)
    sign_in user

    @customer.update(enable_external_callback: true, external_callback_url: 'https://example.com/{PLANNING_IDS}/{API_KEY}/{CUSTOMER_ID}')

    plannings = @customer.plannings
    planning_ids = plannings.map(&:id).join(',')

    stub_request(:get, "https://example.com/#{planning_ids}/#{user.api_key}/#{@customer.id}")
      .to_return(status: 200)

    post :external_callback, params: { id: @customer.id, planning_ids: planning_ids }, format: :json
    assert_response :success
    assert_equal 'ok', JSON.parse(response.body)['status']
  end

  test 'should not make external callback when disabled' do
    user = users(:user_one)
    sign_in user

    @customer.update(enable_external_callback: false)

    post :external_callback, params: { id: @customer.id, planning_id: @customer.plannings.first.id, route_id: @customer.plannings.first.routes[1].id }, format: :json
    assert_response :forbidden
  end

  test 'external_callback is forbidden when planning and route external_callback segments are not usable' do
    return unless Role.column_names.include?('planning_toolbar')

    user = users(:user_one)
    @customer.update!(
      enable_external_callback: true,
      external_callback_url: 'https://example.com/{PLANNING_ID}/{API_KEY}/{CUSTOMER_ID}'
    )

    reseller = resellers(:reseller_one)
    ops = Preferences::Catalog.default_planning_toolbar.deep_dup
    ops['planning']['segment_controls']['external_callback'] = {
      'visible' => true, 'usable' => false
    }
    ops['route'] ||= {}
    ops['route']['segment_controls'] ||= {}
    ops['route']['segment_controls']['external_callback'] = {
      'visible' => true, 'usable' => false
    }
    role = Role.create!(
      reseller: reseller,
      name: 'Planning callback view-only role',
      planning_toolbar: ops,
      spaces: Preferences::Catalog.default_spaces
    )
    user.update!(role_id: role.id)
    sign_in user

    planning = @customer.plannings.first
    post :external_callback, params: { id: @customer.id, planning_id: planning.id }, format: :json
    assert_response :forbidden
  ensure
    user.update!(role_id: nil)
    @customer.update_columns(enable_external_callback: false, external_callback_url: nil, external_callback_name: nil)
    role&.destroy
  end

  test 'should handle external callback error' do
    user = users(:user_one)
    sign_in user

    @customer.update(enable_external_callback: true, external_callback_url: 'https://example.com/{PLANNING_ID}')

    planning = @customer.plannings.first

    stub_request(:get, "https://example.com/#{planning.id}")
      .to_return(status: 500)

    post :external_callback, params: { id: @customer.id, planning_id: planning.id }, format: :json
    assert_response :unprocessable_entity
    assert_equal I18n.t('services.external_callback.fail'), JSON.parse(response.body)['error']
  end
end
