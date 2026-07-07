# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

require 'test_helper'

class PlanningStatesControllerTest < ActionController::TestCase
  tests PlanningStatesController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @planning = Planning.where(id: plannings(:planning_one).id).preload_route_details.first!
    sign_in users(:user_one)
    customers(:customer_one).update(job_optimizer_id: nil, job_destination_geocoding_id: nil)
    @planning.planning_states.delete_all
    @planning.capture_state!(trigger: 'move')
    @planning_state = @planning.planning_states.reload.first
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options|
      segments.collect { |_i| [1000, 60, '_ibE_seK_seK_seK'] }
    }) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda { |_url, _mode, _dimensions, row, column, _options|
        [Array.new(row.size) { Array.new(column.size, 0) }]
      }) do
        yield
      end
    end
  end

  test 'index returns grouped planning states' do
    get :index, params: { planning_id: @planning.id, format: :json }

    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
    group = body.find { |item| item['category'] == 'individual' }
    assert group
    assert_equal I18n.t('plannings.states.categories.individual'), group['category_label']
    state = group['states'].find { |item| item['id'] == @planning_state.id }
    assert state
    assert state['statistics_html'].present?
    assert_includes state['statistics_html'], 'route-info'
    assert_equal false, state['pinned']
    assert_equal 3, group['max_pinned']
    assert_equal 0, group['pinned_count']
  end

  test 'pin and unpin planning state' do
    patch :pin, params: { planning_id: @planning.id, id: @planning_state.id, pinned: true, format: :json }

    assert_response :no_content
    assert @planning_state.reload.pinned?

    patch :pin, params: { planning_id: @planning.id, id: @planning_state.id, pinned: false, format: :json }

    assert_response :no_content
    refute @planning_state.reload.pinned?
  end

  test 'pin returns 422 when category pin limit is reached' do
    payload = @planning_state.payload
    3.times do |i|
      @planning.planning_states.create!(
        captured_at: (10 + i).minutes.ago,
        trigger: 'move',
        category: 'individual',
        payload: payload,
        statistics: { 'routes_cost' => i },
        pinned: true
      )
    end

    patch :pin, params: { planning_id: @planning.id, id: @planning_state.id, pinned: true, format: :json }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal I18n.t('plannings.states.pin_limit_reached'), body['error']
    refute @planning_state.reload.pinned?
  end

  test 'index is forbidden when planning_states operation is not visible' do
    u = users(:user_one)
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['planning']['segment_controls']['planning_states'] = { 'visible' => false, 'usable' => false }
    role = Role.create!(
      reseller: resellers(:reseller_one),
      name: "no-planning-states-#{SecureRandom.hex(4)}",
      operations: ops,
      forms: Preferences::Catalog.default_forms
    )
    u.update!(role_id: role.id)
    sign_in u

    get :index, params: { planning_id: @planning.id, format: :json }
    assert_response :forbidden
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end

  test 'reapply is forbidden when planning_states operation is visible but not usable' do
    u = users(:user_one)
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['planning']['segment_controls']['planning_states'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: resellers(:reseller_one),
      name: "planning-states-disabled-#{SecureRandom.hex(4)}",
      operations: ops,
      forms: Preferences::Catalog.default_forms
    )
    u.update!(role_id: role.id)
    sign_in u

    patch :reapply, params: { planning_id: @planning.id, id: @planning_state.id, format: :json }
    assert_response :forbidden
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end

  test 'reapply restores planning structure' do
    snapshot_visit_ids =
      @planning_state.payload['routes'].flat_map { |route| route['stops'] }
                     .select { |stop| stop['type'] == 'visit' }
                     .map { |stop| stop['visit_id'] }

    @planning.routes.select(&:vehicle_usage?).each { |route| route.set_visits([], false) }

    patch :reapply, params: { planning_id: @planning.id, id: @planning_state.id, format: :json }

    assert_response :success
    @planning.reload
    current_visit_ids = @planning.routes.flat_map(&:stops).grep(StopVisit).map(&:visit_id)
    assert_equal snapshot_visit_ids.sort, current_visit_ids.sort
  end

  test 'reapply returns full planning show json' do
    patch :reapply, params: { planning_id: @planning.id, id: @planning_state.id, format: :json }

    assert_response :success
    body = JSON.parse(response.body)
    assert body['routes'].present?
    assert_equal @planning.id, body['planning_id']
    assert body.key?('distance')
  end
end
