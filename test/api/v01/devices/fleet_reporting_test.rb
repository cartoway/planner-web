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

class V01::Devices::FleetReportingTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join('test/lib/devices/api_base')
  include ApiBase

  require Rails.root.join('test/lib/devices/fleet_base')
  include FleetBase

  setup do
    @customer = customers(:customer_one)
    @customer.update(devices: { fleet: { enable: true, user: 'driver1', api_key: '123456' } }, enable_vehicle_position: true, enable_stop_status: true)
    set_route
  end

  test 'should get reporting' do
    stub_request(:get, 'http://localhost:8084/api/0.1/reportings?format=json&from=2019-01-01&to=2019-02-01&with_actions=true')
      .with(
        headers: { 'Authorization' => 'Token token=123456', 'Charset' => 'utf-8', 'Content-Type' => 'application/json' })
        .to_return(status: 200, body: '[{"mission_action_final_label":"To do","mission_address":{"city":"bordeaux","country":"france","postalcode":"33000","street":"40 rue de canolle"},"mission_date":"2019-04-17T12:00:00.000+02:00","mission_duration":3600,"mission_external_ref":"mission-r15587-2019_04_17-1312","mission_id":"mission-a8c0f6ff9","mission_location":{"lat":44.828271,"lon":-0.602265},"mission_name":"jean roger Pomme"}]', headers: {})


    get api('devices/fleet/reporting', **{ customer_id: @customer.id, begin_date: '01-01-2019', end_date: '31-01-2019', with_actions: true })
    assert_equal 200, last_response.status
  end

  test 'should parse dates' do
    stub_request(:get, 'http://localhost:8084/api/0.1/reportings?format=json&from=2019-01-01&to=2019-01-31&with_actions=true').
      with(
        headers: { 'Authorization' => 'Token token=123456', 'Charset' => 'utf-8', 'Content-Type' => 'application/json' }).
      to_return(status: 204, body: '', headers: {})


    orig_locale = I18n.locale
    begin
      I18n.locale = :en
      get api('devices/fleet/reporting', **{ customer_id: @customer.id, begin_date: '01-01-2019', end_date: '01-30-2019', with_actions: true })
      assert_equal 204, last_response.status
    ensure
      I18n.locale = orig_locale
    end
  end

end
