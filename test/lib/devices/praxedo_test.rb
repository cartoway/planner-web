require 'test_helper'

class PraxedoTest < ActionController::TestCase

  require Rails.root.join('test/lib/devices/praxedo_base')
  include PraxedoBase

  setup do
    @customer = add_praxedo_credentials customers(:customer_one)
    @service = Planner::Application.config.devices.praxedo
  end

  test 'check authentication' do
    with_stubs [:get_events_wsdl, :get_events] do
      assert_nothing_raised do
        params = {
          login: @customer.devices[:praxedo][:login],
          password: @customer.devices[:praxedo][:password]
        }
        assert @service.check_auth params
      end
    end
  end

  test 'send route' do
    with_stubs [:create_events_wsdl, :create_events] do
      set_route
      assert_nothing_raised do
        response = @service.send_route @customer, @route
        assert response
        assert_equal response.size, 5
        assert response.all? { |r| r[:result_code] == '0' }
      end
    end
  end

  test 'fetch stops' do
    # All 3 stops in route are completed
    # with following quantities from Praxedo:
    # 0 => 30kg / 1 => 10kg / 2 => 5kg
    with_stubs [:search_events_wsdl, :search_events] do
      set_route
      assert_nothing_raised do
        stops_status = @service.fetch_stops(@customer, Time.new(2017, 10, 10, 0, 0, 0, '+02:00'), plannings(:planning_one))
        assert stops_status
        assert stops_status.size, 3
        assert stops_status.each do |status|
          status[:quantities].second[:label] == 'kg'
          Float(status[:quantities].second[:quantity]) > 0
        end
      end
    end
  end

  test 'should update stop status' do
    # All 3 stops in route are completed
    # with following quantities from Praxedo:
    # 0 => 30kg / 1 => 10kg / 2 => 5kg
    with_stubs [:search_events_wsdl, :search_events] do
      planning = plannings(:planning_one)
      planning.routes.select(&:vehicle_usage_id).each { |route|
        route.last_sent_at = Time.now.utc
      }
      planning.save

      planning.fetch_stops_status
      planning.routes.select(&:vehicle_usage_id).each { |route|
        if route.ref == 'route_one'
          # Status are not sync (using TomTom's statuses)
          # assert route.stops.select(&:active).all? { |stop| stop.status == 'Finished' }
          assert_equal [5, 10, 30], route.stops.select{ |s| s.active && s.is_a?(StopVisit) }.map{ |s| s.visit.quantities[2] }
        end
      }
    end
  end

  test 'clear route' do
    with_stubs [:delete_events_wsdl, :delete_events] do
      set_route
      assert_nothing_raised do
        @service.clear_route @customer, @route
      end
    end
  end

  # FIXME: not used for now
  # test 'get vehicles positions' do
  #   with_stubs [:client_geolocalisation_wsdl, :get_last_position_for_agents] do
  #     assert @service.vehicle_pos(@customer)
  #   end
  # end
end
