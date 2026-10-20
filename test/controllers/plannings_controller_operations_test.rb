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
    shortener = Object.new
    def shortener.shorten(url)
      url
    end
    Rails.application.config.stubs(:url_shortener).returns(shortener)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'publish_operation creates from selected routes and opens the operation' do
    route = routes(:route_one_one)
    post :publish_operation, params: {
      id: @planning.id,
      name: 'Secteur A',
      ref: 'OP-A',
      date: Date.current,
      route_ids: [route.id]
    }

    operation = @planning.operations.open_status.last
    assert_redirected_to operation_path(operation)
    assert_equal 'Secteur A', operation.name
    assert_equal 'OP-A', operation.ref
    assert_equal Date.current, operation.date
    assert_equal [route.id], operation.operation_routes.pluck(:route_id)
  end

  test 'publish_operation applies driver contact overrides on vehicle_snapshot' do
    route = routes(:route_one_one)
    post :publish_operation, params: {
      id: @planning.id,
      name: 'Contacts',
      date: Date.current,
      route_ids: [route.id],
      driver_contacts: {
        route.id.to_s => {
          contact_email: 'override@example.com',
          phone_number: '0699988877'
        }
      }
    }

    operation = @planning.operations.open_status.last
    assert_redirected_to operation_path(operation)
    snap = operation.operation_routes.find_by!(route_id: route.id).vehicle_snapshot
    assert_equal 'override@example.com', snap['contact_email']
    assert_equal '0699988877', snap['phone_number']
    refute_equal 'override@example.com', route.vehicle_usage.vehicle.reload.contact_email
  end

  test 'publish_operation with transmit sends driver emails' do
    route = routes(:route_one_one)
    @planning.customer.update_columns(enable_email_driver: true, enable_sms_driver: false)
    before = ActionMailer::Base.deliveries.size

    post :publish_operation, params: {
      id: @planning.id,
      name: 'Transmit',
      date: Date.current,
      route_ids: [route.id],
      transmit: 'Créer et transmettre',
      driver_contacts: {
        route.id.to_s => { contact_email: 'chauffeur@example.com' }
      }
    }

    operation = @planning.operations.open_status.last
    assert_redirected_to operation_path(operation)
    sent = ActionMailer::Base.deliveries.drop(before)
    assert sent.any?
    assert_includes sent.flat_map(&:to), 'chauffeur@example.com'
  end

  test 'publish_operation with transmit respects per-row email channel when both are enabled' do
    route = routes(:route_one_one)
    @planning.customer.update_columns(enable_email_driver: true, enable_sms_driver: true)
    Operations::SendDriverSms.expects(:call).never
    before = ActionMailer::Base.deliveries.size

    post :publish_operation, params: {
      id: @planning.id,
      name: 'Transmit email only',
      date: Date.current,
      route_ids: [route.id],
      transmit: '1',
      driver_contacts: {
        route.id.to_s => { contact_email: 'mail-only@example.com', phone_number: '0601020304', channel: 'email' }
      }
    }

    operation = @planning.operations.open_status.last
    assert_redirected_to operation_path(operation)
    sent = ActionMailer::Base.deliveries.drop(before)
    assert_includes sent.flat_map(&:to), 'mail-only@example.com'
    assert_equal 'email', operation.operation_routes.find_by!(route_id: route.id).last_sent_to
  end

  test 'publish_operation with transmit respects per-row sms channel when both are enabled' do
    route = routes(:route_one_one)
    @planning.customer.update_columns(enable_email_driver: true, enable_sms_driver: true)
    Operations::SendDriverSms.stubs(:messaging_service).returns(fake_sms_messaging)
    before = ActionMailer::Base.deliveries.size

    post :publish_operation, params: {
      id: @planning.id,
      name: 'Transmit sms only',
      date: Date.current,
      route_ids: [route.id],
      transmit: '1',
      driver_contacts: {
        route.id.to_s => { contact_email: 'sms-only@example.com', phone_number: '0601020304', channel: 'sms' }
      }
    }

    operation = @planning.operations.open_status.last
    assert_redirected_to operation_path(operation)
    assert_equal before, ActionMailer::Base.deliveries.size
    assert_equal 'sms', operation.operation_routes.find_by!(route_id: route.id).last_sent_to
  end

  test 'publish_operation without transmit does not send emails' do
    route = routes(:route_one_one)
    @planning.customer.update_columns(enable_email_driver: true, enable_sms_driver: false)
    before = ActionMailer::Base.deliveries.size

    post :publish_operation, params: {
      id: @planning.id,
      name: 'No transmit',
      date: Date.current,
      route_ids: [route.id],
      driver_contacts: {
        route.id.to_s => { contact_email: 'chauffeur@example.com' }
      }
    }

    assert_redirected_to operation_path(@planning.operations.open_status.last)
    assert_equal before, ActionMailer::Base.deliveries.size
  end

  test 'publish_operation rejects a past date' do
    route = routes(:route_one_one)
    # Users are in Hawaii: compare against Date.current in that zone, not UTC.
    past = Time.use_zone(users(:user_one).time_zone) { Date.current - 1 }
    post :publish_operation, params: {
      id: @planning.id,
      name: 'Past',
      date: past,
      route_ids: [route.id]
    }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.past_date'), flash[:alert]
    assert_nil @planning.operations.open_status.last
  end

  test 'publish_operation rejects a route already in an open operation' do
    route = routes(:route_one_one)
    Operations::PublishFromPlanning.call(planning: @planning, date: Date.current, route_ids: [route.id])

    post :publish_operation, params: {
      id: @planning.id,
      name: 'Collision',
      date: Date.current,
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

  test 'sync_operation with selection does not orphan omitted routes' do
    route_a = routes(:route_one_one)
    route_b = routes(:route_three_one)
    operation = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_a.id, route_b.id])
    kept_a = operation.operation_routes.find_by!(route_id: route_a.id)
    kept_b = operation.operation_routes.find_by!(route_id: route_b.id)

    post :sync_operation, params: {
      id: @planning.id,
      operation_id: operation.id,
      selection: '1',
      route_ids: [route_a.id]
    }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.synced'), flash[:notice]
    assert_equal 'active', kept_a.reload.sync_state
    assert_equal 'active', kept_b.reload.sync_state
    assert_equal [route_a.id, route_b.id].sort, operation.reload.custom_attributes['_route_ids'].map(&:to_i).sort
  end

  test 'sync_operation with desync_route_ids destroys those routes' do
    route_a = routes(:route_one_one)
    route_b = routes(:route_three_one)
    operation = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [route_a.id, route_b.id])
    kept = operation.operation_routes.find_by!(route_id: route_a.id)
    dropped_id = operation.operation_routes.find_by!(route_id: route_b.id).id

    post :sync_operation, params: {
      id: @planning.id,
      operation_id: operation.id,
      selection: '1',
      route_ids: [route_a.id],
      desync_route_ids: [route_b.id]
    }

    assert_redirected_to edit_planning_path(@planning)
    assert_equal I18n.t('execution.synced'), flash[:notice]
    assert_equal 'active', kept.reload.sync_state
    assert_nil OperationRoute.find_by(id: dropped_id)
    assert_equal [route_a.id], operation.reload.custom_attributes['_route_ids'].map(&:to_i)
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

  test 'operation modal prefills date from planning when present and not past' do
    today = Time.use_zone(users(:user_one).time_zone) { Date.current }
    @planning.update!(date: today + 2)

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select '#execution-operation-date[value=?]', @planning.date.strftime('%Y-%m-%d')
    assert_select '#execution-operation-date[min=?]', today.strftime('%Y-%m-%d')
  end

  test 'operation modal clamps past planning date to today' do
    today = Time.use_zone(users(:user_one).time_zone) { Date.current }
    assert @planning.date.present?
    assert_operator @planning.date, :<, today

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select '#execution-operation-date[value=?]', today.strftime('%Y-%m-%d')
  end

  test 'operation modal falls back to offset date when planning has no date' do
    @planning.update!(date: nil)
    expected = Time.use_zone(users(:user_one).time_zone) {
      Date.current + @planning.customer.operation_date_offset_default
    }

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select '#execution-operation-date[value=?]', expected.strftime('%Y-%m-%d')
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
      route_ids: [routes(:route_three_one).id],
      allow_past: true
    )
    historized.update!(status: 'historized')

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_includes @response.body, 'planning-execution'
    assert_includes @response.body, 'planning-execution-card'
    assert_includes @response.body, 'planning-execution-progress'
    assert_includes @response.body, 'status-segments'
    assert_includes @response.body, I18n.t('operations.index.stops_count', treated: open_op.board_counts.values_at(:delivered, :failed, :exception).sum, total: open_op.board_counts[:total])
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
    assert_includes @response.body, 'sync-route-selector'
    assert_includes @response.body, 'planning-execution-route-extras'
    assert_includes @response.body, 'data-taken-by-date'
    assert_includes @response.body, I18n.t('execution.open_tracking')
    assert_includes @response.body, I18n.t('execution.badge_dirty')
    assert_includes @response.body, I18n.t('execution.modal.stops_count', count: routes(:route_one_one).size_active)
    assert_operator @response.body.index('planning-execution-card'), :<, @response.body.index('planning-execution-historized')
    tools_idx = @response.body.index(/id=["']planning_tools["']/)
    execution_idx = @response.body.index(/id=["']planning-execution["']/)
    global_tools_idx = @response.body.index(/id=["']global_tools["']/)
    assert tools_idx && execution_idx && global_tools_idx
    assert_operator tools_idx, :<, execution_idx
    assert_operator execution_idx, :<, global_tools_idx
    assert_includes @response.body, open_op.ref.presence || open_op.name
    assert_select ".planning-execution-sync[data-operation-id=#{open_op.id}]"
    assert_select ".planning-execution-badge[data-operation-id=#{open_op.id}].label-warning"
    assert_no_match(/data-route-changes=/, @response.body)
  end

  test 'data_header js includes execution freshness for open operations' do
    fresh = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Fresh',
      date: Date.current,
      route_ids: [routes(:route_one_one).id]
    )
    dirty = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Dirty',
      date: Date.current,
      route_ids: [routes(:route_three_one).id]
    )
    dirty.update_columns(structure_fingerprint: 'stale')

    get :data_header, params: { planning_id: @planning.id, format: :js }, xhr: true

    assert_response :success
    assert_includes @response.body, 'planning:execution:status'
    assert_match(/"id":#{fresh.id}.*"fresh":true/m, @response.body)
    assert_match(/"id":#{dirty.id}.*"fresh":false/m, @response.body)
  end

  test 'operation_sync_preview returns route membership and dirty flags' do
    route = routes(:route_one_one)
    operation = Operations::PublishFromPlanning.call(
      planning: @planning,
      name: 'Sync',
      date: Date.current,
      route_ids: [route.id]
    )

    get :operation_sync_preview, params: { planning_id: @planning.id, operation_id: operation.id, format: :json }

    assert_response :success
    body = JSON.parse(@response.body)
    assert_includes body['route_ids'], route.id
    assert body['route_changes'][route.id.to_s]['in_operation']
    assert body['route_changes'][route.id.to_s].key?('dirty')
    assert_equal true, body['fresh']
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
    assert_select "#execution-route-selector .searchable-checklist-dropdown-option[data-item-id=#{empty.id}][data-unavailable=1]"
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

  test 'sync modal uses the same searchable route selector and filters as create' do
    with_stops = routes(:route_one_one)
    empty = routes(:route_three_one)
    empty.route_data.update_columns(size_active: 0, stops_size: 0)
    with_stops.update_columns(hidden: false, locked: false)
    empty.update_columns(hidden: false, locked: false)
    tag = tags(:tag_one)
    with_stops.vehicle_usage.vehicle.tags << tag unless with_stops.vehicle_usage.vehicle.tags.include?(tag)

    get :edit, params: { id: @planning.id }

    assert_response :success
    assert_select '#sync-route-selector[data-searchable-checklist-dropdown]'
    assert_select '#sync-route-selector [data-searchable-checklist-toggle]'
    assert_select '#sync-route-selector .searchable-checklist-dropdown-menu'
    assert_select '#sync-route-selector [data-searchable-checklist-action=all]'
    assert_select '#sync-route-selector [data-searchable-checklist-action=clear]'
    assert_select '#sync-route-selector [data-searchable-checklist-action=reverse]'
    assert_select '#sync-route-selector [data-searchable-checklist-action=visible]'
    assert_select '#sync-route-selector [data-searchable-checklist-filter]'
    assert_select "#sync-route-selector [data-searchable-checklist-tag-filter][value=#{tag.id}]"
    assert_select "#sync-route-selector .searchable-checklist-dropdown-option[data-item-id=#{with_stops.id}]"
    assert_select "#sync-route-selector .searchable-checklist-dropdown-option[data-item-id=#{empty.id}][data-unavailable=1]"
    assert_select "#sync-route-selector .searchable-checklist-dropdown-option[data-tag-ids='#{tag.id}']"
    assert_select "#planning-sync-modal .planning-execution-route[data-route-id=#{with_stops.id}]"
    assert_select "#planning-sync-modal .sync-route-checkbox.form-check-input"
    assert_select '#planning-sync-modal .planning-execution-route-extras'
    assert_select '#planning-sync-modal [data-sync-routes]', count: 0
    assert_includes @response.body, I18n.t('execution.modal.routes_with_stops_only')
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

  test 'planning json loads today operations in one query for all routes' do
    Time.use_zone(users(:user_one).time_zone) do
      Operations::PublishFromPlanning.call(
        planning: @planning,
        date: Date.current,
        route_ids: @planning.routes.select(&:vehicle_usage_id).map(&:id)
      )
    end

    operation_route_queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      operation_route_queries += 1 if sql.include?('operation_routes') && sql.include?('FROM "operation_routes"')
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      get :show, params: { id: @planning.id }, format: :json
    end

    assert_response :success
    assert_operator operation_route_queries, :<=, 1,
                    "expected at most one operation_routes lookup, got #{operation_route_queries}"
  end

  private

  def fake_sms_messaging
    messaging = Object.new
    messaging.define_singleton_method(:content) { |*| 'ok' }
    messaging.define_singleton_method(:send_message) { |*| true }
    klass = Class.new {
      def self.name
        'FakeSms'
      end
    }
    messaging.define_singleton_method(:class) { klass }
    messaging
  end
end
