require 'test_helper'

class Admin::CustomersControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @controller = CustomersController.new
    @customer = customers(:customer_one)
    sign_in users(:user_admin)
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_valid response
  end

  test 'should get edit' do
    get :edit, params: { id: @customer }
    assert_response :success
    assert_valid response
  end

  test 'should create customer' do
    assert_difference('Customer.count') do
      assert_difference('Vehicle.count', 2) do
        assert_difference('VehicleUsage.count', 2) do
          post :create, params: { customer: { name: 'new', max_vehicles: 2, default_country: 'France', speed_multiplier: 1, profile_id: profiles(:profile_one), router: routers(:router_one).id.to_s + '_time' }}
        end
      end
    end
    assert_redirected_to edit_customer_path(assigns(:customer))
  end

  test 'should use environment variable for customer test' do
    begin
      Mapotempo::Application.config.customer_test_default = true
      sign_in users(:user_admin)
      get :new
      assert_response :success
      assert_select 'form input' do
        assert_select "[name='customer[test]']" do
          assert_select '[value=?]', '1'
        end
      end
    ensure
      Mapotempo::Application.config.customer_test_default = true
    end

    begin
      Mapotempo::Application.config.customer_test_default = false
      sign_in users(:user_admin)
      get :new
      assert_response :success
      assert_select 'form input' do
        assert_select "[name='customer[test]']" do
          assert_select '[value=?]', '0'
        end
      end
    ensure
      Mapotempo::Application.config.customer_test_default = true
    end
  end

  test 'should update customer with different optimization time' do
    [
      {name: 'no time'},
      {optimization_minimal_time: 3, optimization_time: 5},
      {optimization_minimal_time: 3, optimization_time: nil}
    ].each do |obj|
      assert patch :update, params: { id: @customer, customer: obj }
    end
  end

  test 'should not update customer with different optimization time' do
    [
      {optimization_minimal_time: 5, optimization_time: 3},
      {optimization_minimal_time: nil, optimization_time: 4}
    ].each do |obj|
      assert patch :update, params: { id: @customer, customer: obj }
    end
  end

  test 'should update customer' do
    assert_difference('Vehicle.count', 1) do
      assert_difference('VehicleUsage.count', @customer.vehicle_usage_sets.size) do
        assert_difference('Route.count', @customer.plannings.length) do
          Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
            patch :update, params: { id: @customer, params: { customer: { duration: '00:30', enable_orders: !@customer.enable_orders, max_vehicles: @customer.max_vehicles + 1 }}}
          end
        end
      end
    end
    assert_redirected_to edit_customer_path(assigns(:customer))
  end

  test 'should update customer by decreasing vehicles' do
    assert_difference('Vehicle.count', -1) do
      assert_difference('VehicleUsage.count', -@customer.vehicle_usage_sets.size) do
        assert_difference('Route.count', -@customer.plannings.length) do
          Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
            patch :update, params: { id: @customer, customer: { max_vehicles: @customer.max_vehicles - 1 }}
          end
        end
      end
    end
    assert_redirected_to edit_customer_path(assigns(:customer))
  end

  test 'should update customer with locale' do
    orig_locale = I18n.locale
    begin
      # EN
      I18n.locale = I18n.default_locale = :en
      assert_equal :en, I18n.locale
      patch :update, params: { id: @customer, customer: { name: 123, router_dimension: 'distance', end_subscription: '10-30-2016' }}
      assert_redirected_to [:edit, @customer]
      assert @customer.reload.end_subscription.strftime("%d-%m-%Y") == '30-10-2016'

      # FR
      I18n.locale = I18n.default_locale = :fr
      assert_equal :fr, I18n.locale
      patch :update, params: { id: @customer, customer: { name: 123, router_dimension: 'distance', end_subscription: '30-10-2016' }}
      assert_redirected_to [:edit, @customer]
      assert @customer.reload.end_subscription.strftime("%d-%m-%Y") == '30-10-2016'
    ensure
      I18n.locale = I18n.default_locale = orig_locale
    end
  end

  test 'should destroy vehicles' do
    assert_difference('Vehicle.count', -1) do
      assert_difference('VehicleUsage.count', -@customer.vehicle_usage_sets.size) do
        delete :delete_vehicle, params: { id: @customer.id, vehicle_id: vehicles(:vehicle_one).id }
      end
    end
    assert_redirected_to edit_customer_path(assigns(:customer))
  end

  test 'should destroy customer' do
    assert_difference('Customer.count', -1) do
      delete :destroy, params: { id: @customer }
    end

    assert_redirected_to customers_path
  end

  test 'should destroy multiple customer' do
    assert_difference('Customer.count', -2) do
      delete :destroy_multiple, params: { customers: { customers(:customer_one).id => 1, customers(:customer_one_other).id => 1 }}
    end

    assert_redirected_to customers_path
  end
end
