# Copyright © Mapotempo, 2017
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'test_helper'

class V01::Devices::PraxedoTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join('test/lib/devices/api_base')
  include ApiBase

  require Rails.root.join('test/lib/devices/praxedo_base')
  include PraxedoBase

  setup do
    @customer = add_praxedo_credentials(customers(:customer_one))
  end

  def planning_api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings#{part}.json?api_key=testkey1&" + param.collect { |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should authenticate' do
    with_stubs [:get_events_wsdl, :get_events] do
      get api("devices/praxedo/auth/#{@customer.id}", params_for(:praxedo, @customer))
      assert_equal 204, last_response.status
    end
  end

  test 'should send route' do
    with_stubs [:create_events_wsdl, :create_events] do
      set_route
      post api('devices/praxedo/send', { customer_id: @customer.id, route_id: @route.id })
      assert_equal 201, last_response.status, last_response.body
      @route.reload
      assert @route.reload.last_sent_at

      assert_equal(
        {
          'id' => @route.id,
          'last_sent_to' => 'Praxedo',
          'last_sent_at' => @route.last_sent_at.iso8601(3),
          'last_sent_at_formatted' => I18n.l(@route.last_sent_at)
        },
        JSON.parse(last_response.body))
    end
  end

  test 'should send multiple routes' do
    set_route
    with_stubs [:create_events_wsdl, :create_events] do
      planning = plannings(:planning_one)
      post api('devices/praxedo/send_multiple', { customer_id: @customer.id, planning_id: planning.id })
      assert_equal 201, last_response.status, last_response.body
      routes = planning.routes.select(&:vehicle_usage_id)
      routes.each(&:reload)
      routes.each { |route|
        assert_equal([{ 'id' => route.id, 'last_sent_to' => 'Praxedo', 'last_sent_at' => route.last_sent_at.iso8601(3), 'last_sent_at_formatted' => I18n.l(route.last_sent_at) }], JSON.parse(last_response.body)) if route.ref == 'route_one'
      }
    end
  end

  test 'should fetch stops into operation actual quantities' do
    customers(:customer_one).update(job_optimizer_id: nil)
    with_stubs [:search_events_wsdl, :search_events] do
      @customer.update_attribute(:enable_stop_status, true)
      set_route
      planning = @route.planning
      Operation.where(customer_id: @customer.id).delete_all
      operation = Operations::PublishFromPlanning.call(planning: planning, route_ids: [@route.id])

      Operations::FetchDeviceStopsStatus.call(operation: operation)

      kg_id = @customer.deliverable_units.find { |du| du.label == 'kg' }.id.to_s
      quantities = operation.operation_stops.where.not(visit_id: nil).map { |os|
        os.reload.actual_quantities&.dig('deliveries', kg_id)
      }.compact.map(&:to_f).sort
      assert_equal [5.0, 10.0, 30.0], quantities
    end
  ensure
    Operation.where(customer_id: @customer.id).delete_all
  end

end
