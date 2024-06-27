require 'test_helper'

class CustomersControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    request.host = @reseller.host
    @customer = customers(:customer_one)
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
      Mapotempo::Application.config.manage_vehicles_only_admin = true
      sign_in users(:user_one)
      get :edit, params: { id: @customer.id }
      assert_response :success
      assert_select 'form input' do
        assert_select "[name='customer[max_vehicles]']" do
          assert_select '[disabled=?]', 'disabled'
        end
      end
    ensure
      Mapotempo::Application.config.manage_vehicles_only_admin = false
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
      orig_validate_during_duplication = Mapotempo::Application.config.validate_during_duplication
      Mapotempo::Application.config.validate_during_duplication = false

      @customer.plannings[1].routes[1].stops[0].index = 666
      @customer.plannings[1].routes[1].stops[0].save!

      sign_in users(:user_admin)
      assert_difference('Customer.count', 1) do
        patch :duplicate, params: { id: @customer.id }
      end
    ensure
      Mapotempo::Application.config.validate_during_duplication = orig_validate_during_duplication
    end
  end

  test 'should dump customer for export' do
    sign_in users(:user_admin)

    get :export, params: { id: @customer.id }

    assert_response :success
  end

  test 'should render import action if no file is uploaded on import' do
    sign_in users(:user_admin)

    post :upload_dump, params: { customer: { profile_id: profiles(:profile_one).id, router_id: routers(:router_one).id, layer_id: layers(:layer_one).id }}

    assert_template :import
  end
end
