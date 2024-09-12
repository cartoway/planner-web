require 'test_helper'

class V01::CustomerTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
  end

  def api(part = nil, param = {}, format = 'json')
    part = part ? '/' + part.to_s : ''
    "/api/0.1/customers#{part}.#{format}?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  def api_admin(part = nil, format = 'json', params = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/customers#{part}.#{format}?api_key=adminkey&" + params.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should list customers' do
    get api_admin
    assert last_response.ok?, last_response.body
    assert_equal resellers(:reseller_one).customers.size, JSON.parse(last_response.body).size
  end

  test 'should not list customers' do
    get api
    assert_equal 403, last_response.status, 'Bad response: ' + last_response.body
  end

  test 'should return a customer' do
    get api('ref:' + @customer.ref)
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body, symbolize_names: true)
    assert_equal @customer.name, json[:name]
    assert_equal @customer.ref, json[:ref]

    get api_admin(@customer.id)
    assert last_response.ok?, last_response.body
  end

  test 'should not return a customer' do
    # XML TESTS
    get api(customers(:customer_two).id, {}, 'xml')
    assert_equal 404, last_response.status, 'Bad response for XML request: ' + last_response.body

    get api_admin(customers(:customer_two).id, 'xml')
    assert_equal 404, last_response.status, 'Bad response for XML request: ' + last_response.body

    # JSON TESTS
    get api(customers(:customer_two).id, {}, 'json')
    assert_equal 404, last_response.status, 'Bad response for JSON request: ' + last_response.body

    get api_admin(customers(:customer_two).id, 'json')
    assert_equal 404, last_response.status, 'Bad response for JSON request: ' + last_response.body
  end

  test 'should update a customer' do
    @customer.devices[:tomtom] = {enable: true}
    @customer.save!
    put api(@customer.id), { devices: {tomtom: {user: 'user_abcd'}}.to_json, ref: 'ref-abcd', router_options: {motorway: true, trailers: 2, weight: 10, hazardous_goods: 'gas'}, optimization_minimal_time: 3, optimization_time: 5 }
    assert last_response.ok?, last_response.body

    get api(@customer.id)
    assert last_response.ok?, last_response.body
    customer_response = JSON.parse(last_response.body, symbolize_names: true)
    assert 'ref-abcd' != customer_response[:ref], last_response.body

    assert customer_response[:devices][:tomtom][:enable]
    assert_equal 'user_abcd', customer_response[:devices][:tomtom][:user], last_response.body

    # FIXME: replace each assertion by one which checks if hash is included in another
    assert_equal 10, customer_response[:router_options][:weight]
    assert_equal true, customer_response[:router_options][:motorway]
    assert_equal 2, customer_response[:router_options][:trailers]
    assert_equal 'gas', customer_response[:router_options][:hazardous_goods]

    assert_equal 3, customer_response[:optimization_minimal_time]
    assert_equal 5, customer_response[:optimization_time]
  end

  test 'should not update customer with invalid router options' do
    put api(@customer.id), {router_options: {width: '3,55'}}.to_json, 'CONTENT_TYPE' => 'application/json'
    errors = JSON.parse(last_response.body)
    assert_equal errors['message'], 'router_options[width] is invalid'
  end

  test 'should update a customer without modifying max vehicles' do
    begin
      Mapotempo::Application.config.manage_vehicles_only_admin = true
      assert_no_difference('Vehicle.count') do
        put api(@customer.id), { max_vehicles: @customer.max_vehicles + 1 }
        assert last_response.ok?, last_response.body
      end
    ensure
      Mapotempo::Application.config.manage_vehicles_only_admin = false
    end
  end

  test 'should update a customer in admin' do
    assert_difference('Vehicle.count', 1) do
      assert_difference('VehicleUsage.count', @customer.vehicle_usage_sets.size) do
        assert_difference('Route.count', @customer.plannings.length) do
          Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
            put api_admin(@customer.id), { devices: {tomtom_id: "user_abcd"}.to_json, ref: 'ref-abcd', max_vehicles: @customer.max_vehicles + 1 }
            assert last_response.ok?, last_response.body
          end
        end
      end
    end
    assert_not_nil Route.last.stop_distance

    get api(@customer.id)
    assert last_response.ok?, last_response.body
    response = JSON.parse(last_response.body, symbolize_names: true)

    assert_equal 'user_abcd', response[:devices][:tomtom_id]
    assert_equal 'ref-abcd', response[:ref]
    assert_equal 3, response[:max_vehicles]
  end

  test 'should not update a customer' do
    customer = customers(:customer_two)
    customer.ref = 'new ref'

    put api_admin(customer.id), customer.attributes.merge('router_dimension' => customer.router_dimension, 'advanced_options' => {})
    assert_equal 404, last_response.status, 'Bad response: ' + last_response.body

    put api(customer.id), customer.attributes.merge('router_dimension' => customer.router_dimension, 'advanced_options' => {})
    assert_equal 404, last_response.status, 'Bad response: ' + last_response.body
  end

  test 'should create a customer' do
    begin
      # test with 2 different configs
      manage_vehicles_only_admin = Mapotempo::Application.config.manage_vehicles_only_admin
      [true, false].each { |v|
        Mapotempo::Application.config.manage_vehicles_only_admin = v

        assert_difference('Customer.count', 1) do
          assert_difference('Store.count', 1) do
            assert_difference('VehicleUsageSet.count', 1) do
              assert_difference('Vehicle.count', 5) do
                post api_admin, {name: 'new cust', max_vehicles: 5, default_country: 'France', router_id: @customer.router_id, profile_id: @customer.profile_id, visit_duration: '00:02:30'}
                assert last_response.created?, last_response.body
                assert_equal 5, JSON.parse(last_response.body)['max_vehicles']
                assert_equal '00:02:30', JSON.parse(last_response.body)['visit_duration']
              end
            end
          end
        end
      }
    ensure
      Mapotempo::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  # We do not want to test if ref is uniq
  # test 'should not create a customer' do
  #   assert_no_difference 'Customer.count' do
  #     post api_admin, { name: 'new cust', ref: @customer.ref, default_country: 'France', max_vehicles: 2, router_id: @customer.router_id, profile_id: @customer.profile_id }
  #     assert_equal 400, last_response.status, 'Bad response: ' + last_response.body
  #
  #     post api, { name: 'new cust', default_country: 'France', max_vehicles: 2, router_id: @customer.router_id, profile_id: @customer.profile_id }
  #     assert_equal 403, last_response.status, 'Bad response: ' + last_response.body
  #   end
  # end

  test 'should destroy a customer' do
    assert_difference('Customer.count', -1) do
      delete api_admin('ref:' + @customer.ref)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should not destroy a customer' do
    assert_no_difference('Customer.count') do
      delete api_admin('ref:' + customers(:customer_two).ref)
      assert_equal 404, last_response.status, 'Bad response: ' + last_response.body

      delete api(@customer.id)
      assert_equal 403, last_response.status, 'Bad response: ' + last_response.body
    end
  end

  test 'should get job' do
    get api("#{@customer.id}/job/#{@customer.job_optimizer_id}")
    assert last_response.ok?, last_response.body
  end

  test 'should delete job' do
    assert_difference('Delayed::Backend::ActiveRecord::Job.count', -1) do
      delete api("#{@customer.id}/job/#{@customer.job_destination_geocoding_id}")
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should duplicate customer' do
    assert_difference('Customer.count', +1) do
      patch api_admin(@customer.id.to_s + '/duplicate')
      assert_equal Customer.last.id, JSON.parse(last_response.body, symbolize_names: true)[:id], last_response.body
      assert last_response.ok?, last_response.body
    end
  end

  test 'should not duplicate customer' do
    assert_no_difference('Customer.count') do
      patch api_admin(customers(:customer_two).id.to_s + '/duplicate')
      assert_equal 404, last_response.status, 'Bad response: ' + last_response.body

      patch api(@customer.id.to_s + '/duplicate')
      assert_equal 403, last_response.status, 'Bad response: ' + last_response.body
    end
  end

  test 'Should duplicate customer without users' do
    assert_difference 'Customer.count', +1 do
      assert_no_difference 'User.count' do
        patch api_admin(@customer.id.to_s + '/duplicate', 'json', {'exclude_users' => true})
      end
    end
  end

  test 'duplicate customer should keep vehicle tags' do
    assert_difference('Customer.count', +1) do
      @customer.vehicles.each{ |vehicle|
        vehicle.tags << @customer.tags.first
        vehicle.save
      }
      patch api_admin(@customer.id.to_s + '/duplicate')
      Customer.last.vehicles.each.with_index{ |vehicle, index|
        assert vehicle.tags.any?, @customer.vehicles[index].tags.map(&:label)
        assert_equal vehicle.tags.map(&:label), @customer.vehicles[index].tags.map(&:label)
      }
    end
  end

  test 'should update advanced options' do
    @customer.update advanced_options: {enable_test: true}
    params = { import: { destinations: { spreadsheetColumnsDef: { ref_vehicle: "driver" }}}, enable_test: true }
    put api_admin(@customer.id), advanced_options: params.to_json
    assert last_response.ok?, JSON.parse(last_response.body)
    assert_equal params.with_indifferent_access, @customer.reload.advanced_options
    params = { import: { destinations: { spreadsheetColumnsDef: {}}}, enable_test: true }
    put api_admin(@customer.id), advanced_options: params
    assert last_response.ok?, last_response.body
    assert_equal({'enable_test' => 'true'}, @customer.reload.advanced_options)
    put api_admin(@customer.id), advanced_options: { enable_test: nil }
    assert last_response.ok?, last_response.body
    assert_equal({'enable_test' => nil}, @customer.reload.advanced_options)

    params = { import: { destinations: { spreadsheetColumnsDef: { ref_vehicle: 'myDriver' }}}}
    put api(@customer.id), advanced_options: params
    assert last_response.ok?, last_response.body
    assert_equal(params.with_indifferent_access, @customer.reload.advanced_options)
  end
end
