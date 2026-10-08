# frozen_string_literal: true

require 'test_helper'

class PlanningsControllerOperationsTest < ActionController::TestCase
  tests PlanningsController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @planning = plannings(:planning_one)
    sign_in users(:user_one)
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'publish_operation creates from selected routes and stays on edit' do
    route = routes(:route_one_one)
    post :publish_operation, params: {
      id: @planning.id,
      name: 'Secteur A',
      date: '2026-09-30',
      route_ids: [route.id]
    }

    assert_redirected_to edit_planning_path(@planning)
    operation = @planning.operations.open_status.last
    assert_equal 'Secteur A', operation.name
    assert_equal Date.new(2026, 9, 30), operation.date
    assert_equal [route.id], operation.operation_routes.pluck(:route_id)
  end

  test 'publish_operation rejects a route already in an open operation' do
    route = routes(:route_one_one)
    Operations::PublishFromPlanning.call(planning: @planning, date: '2026-09-30', route_ids: [route.id])

    post :publish_operation, params: {
      id: @planning.id,
      name: 'Collision',
      date: '2026-09-30',
      route_ids: [route.id]
    }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.route_conflict'), flash[:alert]
    assert_equal 1, @planning.operations.open_status.count
  end

  test 'sync_operation targets the given operation' do
    route_a = routes(:route_one_one)
    route_b = routes(:route_three_one)
    first = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_a.id])
    second = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_b.id])

    post :sync_operation, params: { id: @planning.id, operation_id: first.id }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.synced'), flash[:notice]
    assert_equal 'in_progress', second.reload.status
  end

  test 'sync_operation with selection orphans deselected routes' do
    route_a = routes(:route_one_one)
    route_b = routes(:route_three_one)
    operation = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_a.id, route_b.id])
    kept = operation.operation_routes.find_by!(route_id: route_a.id)
    dropped = operation.operation_routes.find_by!(route_id: route_b.id)

    post :sync_operation, params: {
      id: @planning.id,
      operation_id: operation.id,
      selection: '1',
      route_ids: [route_a.id]
    }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.synced'), flash[:notice]
    assert_equal 'active', kept.reload.sync_state
    assert_equal 'orphaned', dropped.reload.sync_state
    assert dropped.operation_stops.all? { |stop| stop.sync_state == 'orphaned' }
    assert_equal [route_a.id], operation.reload.custom_attributes['_route_ids']
  end

  test 'sync_operation with empty selection is rejected' do
    route = routes(:route_one_one)
    operation = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route.id])

    post :sync_operation, params: {
      id: @planning.id,
      operation_id: operation.id,
      selection: '1',
      route_ids: []
    }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.empty_routes'), flash[:alert]
    assert_equal 'active', operation.operation_routes.find_by!(route_id: route.id).reload.sync_state
  end

  test 'edit shows the operations inventory and create modal' do
    open_op = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Matin',
      date: Date.current,
      route_ids: [routes(:route_one_one).id]
    )
    open_op.update_columns(structure_fingerprint: 'stale')
    historized = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Veille',
      date: Date.current - 1,
      route_ids: [routes(:route_three_one).id]
    )
    historized.update!(status: 'historized')

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_includes @response.body, 'planning-execution'
    assert_includes @response.body, 'planning-execution-card'
    assert_includes @response.body, 'planning-execution-historized'
    assert_includes @response.body, 'is-historized'
    assert_includes @response.body, 'planning-operation-modal'
    assert_includes @response.body, 'planning-sync-modal'
    assert_includes @response.body, 'planning-execution-sync'
    assert_includes @response.body, 'form-switch'
    assert_includes @response.body, 'execution-route-checkbox'
    assert_includes @response.body, 'sync-route-checkbox'
    assert_includes @response.body, 'searchable-checklist-dropdown-menu'
    assert_includes @response.body, 'data-searchable-checklist-filter'
    assert_includes @response.body, 'execution-route-selector'
    assert_includes @response.body, 'planning-execution-route-extras'
    assert_includes @response.body, 'data-taken-by-date'
    assert_includes @response.body, I18n.t('execution.open_tracking')
    assert_includes @response.body, I18n.t('execution.badge_dirty')
    assert_includes @response.body, I18n.t('execution.modal.stops_count', count: routes(:route_one_one).size_active)
    assert_operator @response.body.index('planning-execution-card'), :<, @response.body.index('planning-execution-historized')
    assert_includes @response.body, open_op.ref.presence || open_op.name
  end

  test 'operation modal defaults to visible routes that have stops' do
    with_stops = routes(:route_one_one)
    empty = routes(:route_three_one)
    empty.route_data.update_columns(size_active: 0, stops_size: 0)
    with_stops.update_columns(hidden: false, locked: false)
    empty.update_columns(hidden: false, locked: false)
    tag = tags(:tag_one)
    with_stops.vehicle_usage.vehicle.tags << tag unless with_stops.vehicle_usage.vehicle.tags.include?(tag)

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select "#execution_route_#{with_stops.id}[checked]"
    assert_select "#execution_route_#{empty.id}:not([checked])"
    assert_select "#execution_route_selector-#{empty.id}"
    assert_select "#execution-route-selector .searchable-checklist-dropdown-option[data-item-id=#{empty.id}][data-unavailable=true]"
    assert_select ".planning-execution-route[data-route-id=#{with_stops.id}][data-default-on=true][data-stops='#{with_stops.route_data.size_active}']"
    assert_select ".planning-execution-route.hidden[data-route-id=#{empty.id}][data-default-on=false][data-stops='0']"
    assert_select '#execution-route-selector[data-searchable-checklist-dropdown]'
    assert_select '#execution-route-selector [data-searchable-checklist-toggle]'
    assert_select '#execution-route-selector .searchable-checklist-dropdown-menu'
    assert_select '[data-searchable-checklist-action=all]'
    assert_select '[data-searchable-checklist-action=clear]'
    assert_select '[data-searchable-checklist-action=reverse]'
    assert_select '[data-searchable-checklist-action=visible]'
    assert_select '[data-searchable-checklist-filter]'
    assert_select "[data-searchable-checklist-tag-filter][value=#{tag.id}]"
    assert_select "#execution-route-selector .searchable-checklist-dropdown-option[data-tag-ids='#{tag.id}']"
    assert_select ".planning-execution-route[data-route-id=#{with_stops.id}] .planning-execution-route-row .form-switch .execution-route-checkbox.form-check-input"
    assert_select '.planning-execution-route-extras'
    assert_includes @response.body, I18n.t('execution.modal.routes_with_stops_only')
    assert_includes @response.body, I18n.t('execution.modal.filter_by_tag')
  end

  test 'operation modal treats !(hidden && locked) as visible' do
    locked_only = routes(:route_one_one)
    filtered_out = routes(:route_three_one)
    locked_only.route_data.update_columns(size_active: 2, stops_size: 2)
    filtered_out.route_data.update_columns(size_active: 2, stops_size: 2)
    locked_only.update_columns(hidden: false, locked: true)
    filtered_out.update_columns(hidden: true, locked: true)

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select "#execution_route_#{locked_only.id}[checked]"
    assert_select ".planning-execution-route[data-route-id=#{locked_only.id}][data-default-on=true][data-locked=true][data-hidden=false]"
    assert_select "#execution_route_#{filtered_out.id}:not([checked])"
    assert_select ".planning-execution-route[data-route-id=#{filtered_out.id}][data-default-on=false][data-locked=true][data-hidden=true]"
  end

  test 'summary json exposes route sizes and names for the operation modal refresh' do
    route = routes(:route_one_one)
    route.route_data.update_columns(size_active: 4, stops_size: 5)
    route.update_columns(hidden: false, locked: true, ref: 'REF-OP')

    get :summary, params: { planning_id: @planning.id, format: :json }

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal @planning.id, body['planning_id']
    row = body['routes'].find { |r| r['route_id'] == route.id }
    assert row
    assert_equal false, row['hidden']
    assert_equal true, row['locked']
    assert_includes row['name'], 'REF-OP'
    assert_equal 4, row['data']['size_active']
    assert_equal 5, row['data']['size']
  end

  test 'operation modal renders route name span for live ref updates' do
    route = routes(:route_one_one)
    route.update_columns(ref: 'LIVE-REF', hidden: false)

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select ".planning-execution-route[data-route-id=#{route.id}] .execution-route-name", text: /LIVE-REF/
    assert_select ".planning-execution-route[data-route-id=#{route.id}][data-hidden=false]"
  end

  test 'planning json exposes today operation for the route toolbar button' do
    # Match ApplicationController#set_time_zone (user_one is Hawaii) so operation date equals Date.current during show.
    operation = Time.use_zone(users(:user_one).time_zone) do
      Operations::PublishFromPlanning.call(
        planning: @planning,
        date: Date.current,
        route_ids: [routes(:route_one_one).id]
      )
    end

    get :show, params: { id: @planning.id }, format: :json

    assert_response :success
    route_payload = JSON.parse(@response.body)['routes'].find { |row| row['route_id'] == routes(:route_one_one).id }
    assert route_payload
    assert_equal operation.id, route_payload['today_operation']['id']
    assert_equal operation_path(operation), route_payload['today_operation']['path']
  end

end
