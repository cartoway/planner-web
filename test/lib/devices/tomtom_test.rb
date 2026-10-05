require 'test_helper'

class TomtomTest < ActionController::TestCase

  require Rails.root.join("test/lib/devices/tomtom_base")
  include TomtomBase

  setup do
    @customer = add_tomtom_credentials customers(:customer_one)
    @service = Planner::Application.config.devices.tomtom
  end

  test 'tomtom proxy configuration should get environnement variable' do
    ENV['http_proxy'] = @http_proxy = 'http://127.0.0.1:8080'
    Planner::Application.config.devices.tomtom = Tomtom.new
    Planner::Application.config.devices.tomtom.api_url = 'https://tomtom.example.com'

    %w[savon_client_objects savon_client_address savon_client_orders].each do |fct|
      assert_equal @http_proxy, Planner::Application.config.devices.tomtom.send(fct).globals[:proxy]
    end
  end

  test 'check authentication' do
    with_stubs [:client_objects_wsdl, :show_object_report] do
      params = {
        account: @customer.devices[:tomtom][:account],
        user: @customer.devices[:tomtom][:user],
        password: @customer.devices[:tomtom][:password]
      }
      assert @service.check_auth params
    end
  end

  test 'list devices' do
    with_stubs [:client_objects_wsdl, :show_object_report] do
      assert @service.list_devices @customer
    end
  end

  test 'list vehicles' do
    with_stubs [:client_objects_wsdl, :show_vehicle_report] do
      assert @service.list_vehicles @customer
    end
  end

  test 'list addresses' do
    with_stubs [:address_service_wsdl, :show_address_report] do
      assert @service.list_addresses @customer
    end
  end

  test 'send route as waypoints' do
    with_stubs [:orders_service_wsdl, :send_destination_order] do
      set_route
      assert_nothing_raised do
        @service.send_route @customer, @route, { type: :waypoints }
      end
    end
  end

  test 'send route as orders' do
    with_stubs [:orders_service_wsdl, :send_destination_order] do
      set_route
      assert_nothing_raised do
        @service.send_route @customer, @route, { type: :orders }
      end
    end
  end

  test 'clear route' do
    with_stubs [:orders_service_wsdl, :send_destination_order, :clear_orders] do
      set_route
      assert_nothing_raised do
        @service.clear_route @customer, @route
      end
    end
  end

  test 'get vehicles positions' do
    with_stubs [:client_objects_wsdl, :show_object_report] do
      assert @service.vehicle_pos @customer
    end
  end

  test 'should code and decode stop id' do
    id = 758944
    code = @service.send(:encode_uid, 'plop', id)
    decode = @service.send(:decode_uid, code)
    assert decode, id
  end

  test 'should update operation stop status' do
    with_stubs [:orders_service_wsdl, :show_order_report] do
      planning = plannings(:planning_one)
      Operation.where(customer_id: @customer.id).delete_all
      operation = Operations::PublishFromPlanning.call(planning: planning, route_ids: [routes(:route_one_one).id])

      Operations::FetchDeviceStopsStatus.call(operation: operation)

      stop = operation.operation_stops.find_by(visit_id: routes(:route_one_one).stops.select(&:active).first.visit_id)
      assert_equal 'Started', stop.reload.status
    end
  ensure
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'should show explicit error on timeout' do
    with_stubs [:orders_service_wsdl, :send_destination_order, :timeout] do
      set_route
      assert_raises DeviceServiceError do
        @service.send_route @customer, @route, { type: :orders }
      end
    end
  end
end
