# frozen_string_literal: true

require 'test_helper'

class OperationsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'index lists the published operation' do
    @operation.update_columns(date: Date.current - 1)
    get :index
    assert_response :success
    assert_includes response.body, @operation.name
    assert_includes response.body, 'operations-index'
    assert_includes response.body, I18n.t('execution.open_tracking')
    assert_includes response.body, 'v2-list-filters'
    assert_includes response.body, 'typed-confirm'
    assert_includes response.body, 'btn-danger'
    assert_not_includes response.body, %(<a href="#{operation_path(@operation)}">#{@operation.ref.presence || @operation.name}</a>)
  end

  test 'index filters by status chip and search' do
    open_op = @operation
    open_op.update_columns(ref: 'ref-open', name: 'Open Op', status: 'in_progress')
    historized = Operations::PublishFromPlanning.call(
      planning: @planning,
      date: Date.current - 1,
      route_ids: [routes(:route_three_one).id]
    )
    historized.update!(status: 'historized', ref: 'ref-hist', name: 'Hist Op')

    get :index, params: { status: 'in_progress' }
    assert_response :success
    assert_includes response.body, 'ref-open'
    assert_not_includes response.body, 'ref-hist'

    get :index, params: { q: 'ref-hist' }
    assert_response :success
    assert_includes response.body, 'ref-hist'
    assert_not_includes response.body, 'ref-open'
  end

  test 'destroy removes the operation' do
    id = @operation.id
    delete :destroy, params: { id: id }
    assert_redirected_to operations_path
    assert_equal I18n.t('operations.index.destroyed'), flash[:notice]
    assert_nil Operation.find_by(id: id)
  end

  test 'show hides demo button when deliver demo is off' do
    Rails.application.config.stubs(:url_shortener).returns(stub(shorten: 'http://short.test/route'))
    @planning.customer.update!(devices: { deliver: { enable: true, demo: false } })
    get :show, params: { id: @operation.id }
    assert_response :success
    refute_includes response.body, I18n.t('operations.show.start_demo')
  end

  test 'show starts and stops demo when enabled' do
    Rails.application.config.stubs(:url_shortener).returns(stub(shorten: 'http://short.test/route'))
    @planning.customer.update!(devices: { deliver: { enable: true, demo: true } })
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, I18n.t('operations.show.start_demo')
    assert_includes response.body, I18n.t('operations.show.reset_demo')
    assert_includes response.body, 'operation_demo_actions'

    post :demo, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
    assert @operation.reload.demo_job_id.present?

    delete :stop_demo, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
    assert_nil @operation.reload.demo_job_id

    post :reset_demo, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
  end

  test 'demo actions respond with turbo frame without redirect' do
    Rails.application.config.stubs(:url_shortener).returns(stub(shorten: 'http://short.test/route'))
    @planning.customer.update!(devices: { deliver: { enable: true, demo: true } })
    request.headers['Turbo-Frame'] = 'operation_demo_actions'

    post :demo, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, 'operation_demo_actions'
    assert_includes response.body, I18n.t('operations.show.stop_demo')
    assert @operation.reload.demo_job_id.present?

    delete :stop_demo, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, I18n.t('operations.show.start_demo')
    assert_nil @operation.reload.demo_job_id
  end

  test 'reset demo redirects for a full page reload' do
    Rails.application.config.stubs(:url_shortener).returns(stub(shorten: 'http://short.test/route'))
    @planning.customer.update!(devices: { deliver: { enable: true, demo: true } })

    post :reset_demo, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
  end

  test 'show renders the operation and map payload includes progress' do
    Rails.application.config.stubs(:url_shortener).returns(stub(shorten: 'http://short.test/route'))
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, @operation.name
    assert_includes response.body, 'operation-board'
    assert_match(/map_layers/, response.body)
    assert_match(/map_layers_title/, response.body)
    assert_includes response.body, 'vehicle_one'
    shown = @operation.operation_routes.active_sync.count
    assert_equal shown, response.body.scan('centerVehicle').size
    assert_equal shown, response.body.scan('centerRoute').size
    assert_equal shown, response.body.scan('toggleRouteTrace').size
    assert_includes response.body, 'toggleAllTraces'
    assert_includes response.body, 'operation-route-toolbar'
    assert_includes response.body, 'operation-route-selector-clear'
    assert_includes response.body, 'clearRouteSelectorFilter'
    assert_includes response.body, 'filterRouteSelector'
    assert_includes response.body, I18n.t('web.select2.route_all')
    assert_includes response.body, I18n.t('web.select2.route_clear')
    assert_includes response.body, I18n.t('web.select2.route_reverse')
    assert_equal @operation.operation_routes.active_sync.count, response.body.scan('operation-route-selector-option').size
    assert_includes response.body, I18n.t('operations.show.transmitted')
    units = @operation.board[:units]
    assert_includes response.body, I18n.t('operations.show.deliveries') if units.any? { |unit| unit[:delivery].to_f.positive? }
    assert_includes response.body, I18n.t('operations.show.pickups') if units.any? { |unit| unit[:pickup].to_f.positive? }
    stats_html = response.body[/class='operation-stats'(.*?)<input/m, 1]
    assert stats_html.index(I18n.t('operations.show.transmitted')) < stats_html.index(I18n.t('operations.show.stops'))
    if users(:user_one).header_block_order(:planning).map(&:to_s).include?('distance')
      assert stats_html.index(I18n.t('operations.show.transmitted')) < stats_html.index(I18n.t('display_ui.header_blocks.distance'))
    else
      refute_includes stats_html, I18n.t('display_ui.header_blocks.distance')
    end
    assert_includes response.body, 'operation-route-send'
    assert_equal @operation.operation_routes.active_sync.where.not(vehicle_id: nil).count, response.body.scan("data-channel='email'").size
    assert_includes response.body, 'disabled'
    assert_includes response.body, @operation.operation_routes.planned.first.router_name
    assert_includes response.body, 'fa-house'
    assert_includes response.body, 'selectDepot'
    depot_name = @operation.operation_routes.planned.filter_map { |route| route.vehicle_usage_snapshot.dig('store_start', 'name').presence }.first
    assert depot_name
    assert_includes response.body, depot_name
    assert_includes response.body, 'operation-stop-row'
    assert_includes response.body, 'operation-glyph'
    assert_not_includes response.body, I18n.t('operations.stops.title')
    assert_not_includes response.body, I18n.t('operations.show.close_operation')
    assert_includes response.body, 'turbo-cable-stream-source'
    assert_includes response.body, 'turbo-refresh-method'
    assert_includes response.body, I18n.t('operations.show.send_email')
    assert_includes response.body, I18n.t('plannings.edit.deliver_send.singular.access')
    assert_includes response.body, media_operation_operation_route_path(@operation, @operation.operation_routes.planned.first)
    stop = @operation.operation_stops.where(kind: 'visit').order(:index).first
    stop.update_columns(status: 'delivered')
    get :show, params: { id: @operation.id }
    assert_includes response.body, 'is-delivered'

    get :map, params: { id: @operation.id }
    assert_response :success
    assert_equal 'no-store', response.headers['Cache-Control']
    body = JSON.parse(response.body)
    assert_equal 'FeatureCollection', body['type']
    point = body['features'].find { |feature| feature.dig('properties', 'operation_stop_id') == stop.id }
    assert_equal 'delivered', point['properties']['phase']
    route_feature = body['features'].find { |feature| feature.dig('properties', 'total_count') }
    assert route_feature
    assert route_feature['properties'].key?('progress')
  end

  test 'transmit emails the assigned drivers' do
    before = ActionMailer::Base.deliveries.size
    post :transmit, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
    sent = ActionMailer::Base.deliveries.drop(before)
    assert sent.any?
    assert_includes sent.flat_map(&:to), 'toto@toto.toto'
  end

  test 'sms can be sent after typing a number on a route that had none' do
    @operation.customer.update_columns(enable_sms: true)
    route = @operation.operation_routes.planned.where.not(vehicle_id: nil).first
    snapshot = route.vehicle_snapshot.except('phone_number')
    route.update_columns(vehicle_snapshot: snapshot)
    route.vehicle.update_columns(phone_number: nil)
    get :show, params: { id: @operation.id }
    assert_includes response.body, 'operation-send-sms'
    post :transmit, params: { id: @operation.id, channel: 'sms', routes: { route.id.to_s => { phone_number: '0600000000', send: '1' } } }
    assert_redirected_to operation_path(@operation)
    assert_equal '0600000000', route.reload.vehicle_snapshot['phone_number']
  end

  test 'transmit stores the edited driver email on the operation route' do
    route = @operation.operation_routes.planned.where.not(vehicle_id: nil).first
    before = ActionMailer::Base.deliveries.size
    post :transmit, params: { id: @operation.id, channel: 'email', routes: { route.id.to_s => { contact_email: 'autre@exemple.fr', send: '1' } } }
    assert_redirected_to operation_path(@operation)
    assert_equal 'autre@exemple.fr', route.reload.vehicle_snapshot['contact_email']
    assert route.last_sent_at
    assert_equal 'email', route.last_sent_to
    sent = ActionMailer::Base.deliveries.drop(before)
    assert_includes sent.flat_map(&:to), 'autre@exemple.fr'
  end

  test 'update changes the operation name' do
    get :show, params: { id: @operation.id }
    assert_includes response.body, 'fa-pencil'
    assert_includes response.body, 'nameInput'
    assert_includes response.body, 'd-none'
    @operation.update_columns(status: 'historized')
    patch :update, params: { id: @operation.id, operation: { name: 'Tournée matin' } }
    assert_redirected_to operation_path(@operation)
    assert_equal 'Tournée matin', @operation.reload.name
    patch :update, params: { id: @operation.id, operation: { name: 'Tournée soir' }, format: :json }
    assert_response :success
    assert_equal 'Tournée soir', JSON.parse(response.body)['name']
  end

  test 'update changes the operation date' do
    patch :update, params: { id: @operation.id, operation: { date: '2026-10-01' } }
    assert_redirected_to operation_path(@operation)
    assert_equal Date.new(2026, 10, 1), @operation.reload.date
    patch :update, params: { id: @operation.id, operation: { date: '2026-10-02' }, format: :json }
    assert_response :success
    assert_equal '2026-10-02', JSON.parse(response.body)['date']
  end

  test 'update rejects a date change once historized' do
    @operation.update_columns(status: 'historized', date: Date.new(2026, 9, 1))
    patch :update, params: { id: @operation.id, operation: { date: '2026-10-01' } }
    assert_redirected_to operation_path(@operation)
    assert_equal Date.new(2026, 9, 1), @operation.reload.date
    assert_equal I18n.t('operations.show.date_locked'), flash[:alert]
  end

  test 'index is forbidden when Cartoway Deliver is not enabled' do
    previous = @planning.customer.devices
    @planning.customer.update!(devices: {})
    get :index
    assert_redirected_to root_path
  ensure
    @planning.customer.update!(devices: previous) if previous
  end
end
