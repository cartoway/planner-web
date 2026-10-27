# frozen_string_literal: true

require 'test_helper'
require 'zip'

class OperationsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @planning = plannings(:planning_one)
    @operation = publish_operation!(planning: @planning)
    shortener = Object.new
    def shortener.shorten(url)
      url
    end
    Rails.application.config.stubs(:url_shortener).returns(shortener)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'index lists the published operation' do
    @operation.update_columns(date: Date.current - 1, name: 'Named Op', ref: 'REF-OP')
    get :index
    assert_response :success
    assert_includes response.body, 'Named Op'
    assert_includes response.body, 'REF-OP'
    assert_select '.v2-index-card-title', text: 'Named Op'
    assert_includes response.body, 'operations-index'
    assert_includes response.body, 'v2-index-cards'
    assert_includes response.body, 'v2-index-card'
    assert_includes response.body, 'v2-index-card-actions'

    assert_select '#count.primary.data-info'
    assert_includes response.body, I18n.t('execution.open_tracking')
    assert_includes response.body, 'v2-list-filters'
    assert_includes response.body, 'typed-confirm'
    assert_includes response.body, 'btn-danger'
    assert_not_includes response.body, 'operations-index-table'
    assert_not_includes response.body, %(<a href="#{operation_path(@operation)}">#{@operation.ref.presence || @operation.name}</a>)
    # Card CTA only — menu-left also links the same operation with turbo-frame=main.
    assert_select %(a.btn[href="#{operation_path(@operation)}"][data-turbo-frame="main"][data-turbo-action="advance"]), 1
    assert_select %(a[href="#{export_operation_path(@operation, format: :xlsx)}"]), minimum: 1
    assert_select %(a[href="#{export_operation_path(@operation, format: :zip)}"]), minimum: 1
  end

  test 'menu exposes operations as its own accordion section above plans' do
    get :index
    assert_response :success
    assert_select '#menu-operation > a.menu-section[href="#operationsCollpase"]', 1
    assert_select '#operationsCollpase a[href=?]', operations_path, 1
    assert_select '#planningsCollpase a[href=?]', operations_path, 0
    assert_match(/id=['"]menu-operation['"].*id=['"]menu-plan['"]/m, response.body)
    assert_select %(#operationsCollpase li##{ActionView::RecordIdentifier.dom_id(@operation, :menu)} a[href=?]), operation_path(@operation), 1
    assert_includes response.body, @operation.name
    counter = css_select('#operationsCollpase li').find { |li| li.at_css('i.fa-calendar-check') }
    assert counter, 'expected operations menu counter'
    assert_match(/\b#{@operation.customer.operations.count}\b/, counter.text)
    assert_includes counter.text, I18n.t('operations.menu')
    assert_select %(#operationsCollpase li##{ActionView::RecordIdentifier.dom_id(@operation, :menu)} i.fa-tower-broadcast), 1
  end

  test 'menu lists at most 10 recent operations under total count' do
    customer = @operation.customer
    Operation.where(customer_id: customer.id).where.not(id: @operation.id).delete_all
    11.times do |i|
      Operation.create!(
        customer: customer,
        name: "Menu Op #{i}",
        date: Date.current - i.days,
        status: 'in_progress',
        allow_past_date: true
      )
    end

    get :index
    assert_response :success
    assert_select '#operationsCollpase li[id^="menu_operation_"]', 10
    assert_select '#operationsCollpase li[id^="menu_operation_"] i.fa-tower-broadcast', 10
    counter = css_select('#operationsCollpase li').find { |li| li.at_css('i.fa-calendar-check') }
    assert counter, 'expected operations menu counter'
    assert_match(/\b12\b/, counter.text)
    assert_includes counter.text, I18n.t('operations.menu')
  ensure
    Operation.where(customer_id: customer.id).where.not(id: @operation.id).delete_all
  end

  test 'show wires past-date change confirmation on the operation board' do
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select %([data-v2--operation-show-past-date-confirm-value="#{I18n.t('operations.show.past_date_change_confirm')}"])
  end

  test 'show displays a placeholder when the operation has no ref' do
    @operation.customer.update!(enable_references: true)
    @operation.update_columns(ref: nil)
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select '.operation-header-sub [data-v2--operation-show-target="refLabel"].is-placeholder',
                  text: I18n.t('operations.show.ref_placeholder')
    assert_select %(.operation-header-sub input.operation-ref[placeholder="#{I18n.t('operations.show.ref_placeholder')}"]), 1
  end

  test 'show exposes export spreadsheet and archive links' do
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select %(a[href="#{export_operation_path(@operation, format: :xlsx)}"]), minimum: 1
    assert_select %(a[href="#{export_operation_path(@operation, format: :zip)}"]), minimum: 1
  end

  test 'export xlsx downloads spreadsheet rows with translated headers' do
    get :export, params: { id: @operation.id, format: :xlsx }
    assert_response :success
    assert_equal Mime[:xlsx].to_s, response.media_type
    assert_equal 'PK', response.body.byteslice(0, 2)

    sheet = nil
    Zip::InputStream.open(StringIO.new(response.body)) do |io|
      while (entry = io.get_next_entry)
        if entry.name == 'xl/worksheets/sheet1.xml'
          sheet = io.read.force_encoding('UTF-8')
          break
        end
      end
    end
    assert sheet, 'expected worksheet in xlsx'
    assert_includes sheet, I18n.t('operations.export.columns.operation_name')
    assert_includes sheet, @operation.name
  end

  test 'export zip downloads archive with index and xlsx' do
    get :export, params: { id: @operation.id, format: :zip }
    assert_response :success
    assert_equal 'application/zip', response.media_type

    names = []
    Zip::InputStream.open(StringIO.new(response.body)) do |io|
      while (entry = io.get_next_entry)
        names << entry.name
      end
    end
    assert_includes names, 'index.html'
    assert_includes names, 'stops.xlsx'
  end

  test 'export is forbidden when role lacks export action' do
    user = users(:user_one)
    customer = user.customer
    previous_devices = customer.devices
    customer.update!(devices: { deliver: { enable: true } })

    spaces = Preferences::Catalog.default_spaces.deep_dup
    controls = spaces['operations']['actions']['segment_controls']
    controls['export'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: customer.reseller,
      name: "no-export-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user.update!(role_id: role.id)
    sign_in user

    get :export, params: { id: @operation.id, format: :xlsx }
    assert_response :redirect

    user.update!(role_id: nil)
    customer.update!(devices: previous_devices)
  end

  test 'show and index disable export when export action is not usable' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations']['actions']['segment_controls']['export'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "no-export-ui-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, I18n.t('operations.show.export')
    assert_select '.operation-header-actions-desktop .dropdown-toggle[disabled]', minimum: 1
    assert_select %(a[href="#{export_operation_path(@operation, format: :xlsx)}"]), count: 0

    get :index
    assert_response :success
    assert_includes response.body, I18n.t('operations.show.export')
    assert_select '.v2-index-card-secondary .dropdown-toggle[disabled]', minimum: 1
    assert_select %(a[href="#{export_operation_path(@operation, format: :xlsx)}"]), count: 0
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'index disables destroy when destroy action is not usable' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations']['actions']['segment_controls']['destroy'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "no-destroy-ui-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :index
    assert_response :success
    assert_includes response.body, I18n.t('all.verb.destroy')
    assert_select '.v2-index-card-secondary button.btn-danger[disabled]', minimum: 1
    assert_select "#operation-destroy-#{@operation.id}", count: 0
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'index disables planning button when plannings space is not usable' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['plannings'] = {
      'visible' => true,
      'usable' => false,
      'actions' => spaces['plannings']['actions']
    }
    role = Role.create!(
      reseller: @reseller,
      name: "plannings-disabled-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :index
    assert_response :success
    assert_select '.v2-index-card-secondary button.btn-secondary[disabled]', minimum: 1
    assert_select %(a.btn[href="#{edit_planning_path(@operation.planning)}"]), count: 0

    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select '.operation-header-actions-desktop button.btn-light[disabled]', text: /#{Regexp.escape(I18n.t('operations.show.planning'))}/, minimum: 1
    assert_select %(a.btn[href="#{edit_planning_path(@operation.planning)}"]), count: 0
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'index hides planning button when plannings space is not visible' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['plannings'] = {
      'visible' => false,
      'usable' => false,
      'actions' => spaces['plannings']['actions']
    }
    role = Role.create!(
      reseller: @reseller,
      name: "plannings-hidden-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :index
    assert_response :success
    assert_select %(a.btn[href="#{edit_planning_path(@operation.planning)}"]), count: 0
    assert_select '.v2-index-card-secondary button.btn-secondary[disabled]', count: 0
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'show and index hide export when export action is not visible' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations']['actions']['segment_controls']['export'] = { 'visible' => false, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "hide-export-ui-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :show, params: { id: @operation.id }
    assert_response :success
    assert_not_includes response.body, I18n.t('operations.show.export')

    get :index
    assert_response :success
    assert_not_includes response.body, I18n.t('operations.show.export')
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'index hides destroy when destroy action is not visible' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations']['actions']['segment_controls']['destroy'] = { 'visible' => false, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "hide-destroy-ui-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :index
    assert_response :success
    assert_select '.v2-index-card-secondary button.btn-danger', count: 0
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'show hides send buttons when transmit action is not visible' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations']['actions']['segment_controls']['transmit'] = { 'visible' => false, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "hide-transmit-ui-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :show, params: { id: @operation.id }
    assert_response :success
    assert_not_includes response.body, I18n.t('operations.show.send_drivers')
    assert_not_includes response.body, I18n.t('plannings.edit.deliver_send.singular.transmit')
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'show exposes mobile panes and detail sheet chrome' do
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, 'operation-mobile-panes'
    assert_includes response.body, 'is-mobile-pane-list'
    assert_includes response.body, 'operation-detail-backdrop'
    assert_includes response.body, I18n.t('operations.show.pane_list')
    assert_includes response.body, I18n.t('operations.show.pane_map')
    assert_includes response.body, 'setMobilePane'
  end

  test 'show links to source planning with Plan label in french' do
    assert_equal 'Plan', I18n.t('operations.show.planning', locale: :fr)
    I18n.with_locale(:fr) do
      get :show, params: { id: @operation.id }
    end
    assert_response :success
    assert_select %(a.btn[href="#{edit_planning_path(@operation.planning)}"]), text: /Plan/, minimum: 1
    assert_select %(a.btn[href="#{edit_planning_path(@operation.planning)}"] i.fa-map-location), minimum: 1
  end

  test 'show paints tour left border with vehicle color' do
    route = @operation.operation_routes.first
    route.update_columns(color: '#336699')
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, '--operation-tour-color: #336699'
  end

  test 'show renders status segments on each tour' do
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, 'operation-tour-segments'
    assert_select '.operation-header-progress .operation-segments', 1
    assert_select '.operation-tour-segments', minimum: 1
  end

  test 'show stop rows expose name ref street and city for client search' do
    stop = @operation.operation_stops.find_by!(stop_id: stops(:stop_one_one).id)
    stop.update_columns(
      destination_snapshot: stop.destination_snapshot.merge(
        'name' => 'Chez Dupont',
        'ref' => 'REF-42',
        'street' => '12 rue des Lilas',
        'city' => 'Bordeaux'
      )
    )
    get :show, params: { id: @operation.id }
    assert_response :success
    row = css_select(%(#stop-#{stop.id}[data-label])).first
    assert row, 'expected stop row with data-label'
    label = row['data-label']
    assert_includes label, 'Chez Dupont'
    assert_includes label, 'REF-42'
    assert_includes label, '12 rue des Lilas'
    assert_includes label, 'Bordeaux'
  end

  test 'show exposes en route chip for current phase stops' do
    stop = @operation.operation_stops.find_by!(stop_id: stops(:stop_one_one).id)
    stop.update_columns(status: 'intransit')
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select '.operation-chip[data-phase=current]', text: /#{Regexp.escape(I18n.t('operations.show.filter_en_route'))} 1/
    assert_select %(#stop-#{stop.id}.is-current[data-phase=current]), 1
  end

  test 'show structures tour header zones' do
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select 'details.operation-tour summary.operation-tour-summary', minimum: 1
    assert_select '.operation-tour-head .operation-tour-identity', minimum: 1
    assert_select '.operation-tour-head .operation-tour-progress', minimum: 1
    assert_select '.operation-tour-tools', minimum: 1
  end

  test 'index filters by status chip and search' do
    open_op = @operation
    open_op.update_columns(ref: 'ref-open', name: 'Open Op', status: 'in_progress')
    historized = publish_operation!(
      planning: @planning,
      clear: false,
      date: Date.current - 1,
      route_ids: [routes(:route_three_one).id],
      allow_past: true
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
    @planning.customer.update!(devices: { deliver: { enable: true, demo: false } })
    get :show, params: { id: @operation.id }
    assert_response :success
    refute_includes response.body, I18n.t('operations.show.start_demo')
  end

  test 'show starts and stops demo when enabled' do
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
    @planning.customer.update!(devices: { deliver: { enable: true, demo: true } })
    request.headers['Turbo-Frame'] = 'operation_demo_actions'

    post :demo, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, 'operation_demo_actions'
    assert_includes response.body, I18n.t('operations.show.stop_demo')
    assert_equal 1, response.body.scan(I18n.t('operations.show.reset_demo')).size
    assert @operation.reload.demo_job_id.present?

    delete :stop_demo, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, I18n.t('operations.show.start_demo')
    assert_nil @operation.reload.demo_job_id
  end

  test 'reset demo redirects for a full page reload' do
    @planning.customer.update!(devices: { deliver: { enable: true, demo: true } })

    post :reset_demo, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
  end

  test 'show renders the operation and map payload includes progress' do
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
    route = @operation.operation_routes.planned.first
    assert_includes response.body, Operations::MobileUrl.path(route)
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

  test 'show mobile access skips the url shortener' do
    shortener = mock
    shortener.expects(:shorten).never
    Rails.application.config.stubs(:url_shortener).returns(shortener)

    get :show, params: { id: @operation.id }
    assert_response :success
    route = @operation.operation_routes.planned.first
    assert_includes response.body, Operations::MobileUrl.path(route)
    assert_includes response.body, mobile_url_operation_operation_route_path(@operation, route)
  end

  test 'partial turbo frame skips device status pull' do
    Device.any_instance.stubs(:available_stop_status?).returns(true)
    DeviceService.any_instance.expects(:fetch_stops_status).never
    @request.headers['Turbo-Frame'] = 'operation_demo_actions'

    get :show, params: { id: @operation.id }
    assert_response :success
  end

  test 'list turbo frame main still renders send drivers button' do
    @request.headers['Turbo-Frame'] = 'main'
    @request.headers['X-Turbo-Request-Id'] = 'visit-1'

    get :show, params: { id: @operation.id }
    assert_response :success
    assert_includes response.body, I18n.t('operations.show.send_drivers')
    assert_includes response.body, 'operation-send-drivers'
  end

  test 'historized operation hides send to driver on routes' do
    @operation.update_columns(status: 'historized', closed_at: Time.current)

    get :show, params: { id: @operation.id }
    assert_response :success
    assert_not_includes response.body, I18n.t('plannings.edit.deliver_send.singular.transmit')
    assert_not_includes response.body, I18n.t('operations.show.send_drivers')
    assert_not_includes response.body, "data-channel='email'"
  end

  test 'show disables send buttons when transmit action is not usable' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations']['actions']['segment_controls']['transmit'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "no-transmit-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    get :show, params: { id: @operation.id }

    assert_response :success
    assert_includes response.body, I18n.t('operations.show.send_drivers')
    assert_select '#operation-send-buttons button[disabled]', minimum: 1
    assert_select '.operation-tour-tools .dropdown-toggle[disabled]', minimum: 1
    assert_select '#operation-send-drivers', count: 0
    assert_select '#operation-route-send', count: 0
  ensure
    user&.update!(role_id: nil)
    role&.destroy
  end

  test 'transmit emails the assigned drivers' do
    before = ActionMailer::Base.deliveries.size
    post :transmit, params: { id: @operation.id }
    assert_redirected_to operation_path(@operation)
    sent = ActionMailer::Base.deliveries.drop(before)
    assert sent.any?
    assert_includes sent.flat_map(&:to), 'toto@toto.toto'
    html = sent.last.html_part&.body&.to_s || sent.last.body.to_s
    assert_match(%r{/operations/#{@operation.id}/routes/\d+/mobile}, html)
  end

  test 'send modals keep scrollable body and footer submit' do
    @operation.customer.update_columns(enable_email_destination: true)
    get :show, params: { id: @operation.id }
    assert_response :success
    assert_select '#operation-send-drivers.modal .modal-dialog.modal-dialog-scrollable', 1
    assert_select '#operation-send-drivers form.operation-send-form .modal-body', 1
    assert_select '#operation-send-drivers form.operation-send-form .modal-footer input[type=submit]', 1
    assert_select '#operation-send-drivers .modal-title [data-contacts-total-count]', 1
    assert_select '#operation-send-destinations.modal .modal-dialog.modal-dialog-scrollable', 1
    assert_select '#operation-send-destinations form.operation-send-form .modal-footer input[type=submit]', 1
    assert_select '#operation-send-destinations .modal-title [data-contacts-total-count]', 1
  end

  test 'sms can be sent after typing a number on a route that had none' do
    @operation.customer.update_columns(enable_sms_driver: true)
    route = @operation.operation_routes.planned.where.not(vehicle_id: nil).first
    snapshot = route.vehicle_snapshot.except('phone_number')
    route.update_columns(vehicle_snapshot: snapshot)
    route.vehicle.update_columns(phone_number: nil)
    get :show, params: { id: @operation.id }
    assert_includes response.body, 'operation-send-drivers'
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
    assert_equal I18n.t('operations.show.send_success_email', count: 1), flash[:notice]
  end

  test 'transmit flash reports email and sms counts' do
    @operation.customer.update_columns(enable_email_driver: true, enable_sms_driver: true)
    routes = @operation.operation_routes.planned.where.not(vehicle_id: nil).limit(2).to_a
    skip 'need two vehicle routes' if routes.size < 2
    a, b = routes
    a.update!(vehicle_snapshot: a.vehicle_snapshot.merge('contact_email' => 'a@example.com', 'phone_number' => '0600000001'))
    b.update!(vehicle_snapshot: b.vehicle_snapshot.merge('contact_email' => 'b@example.com', 'phone_number' => '0600000002'))
    messaging = fake_sms_messaging
    Operations::SendDriverSms.stubs(:messaging_service).returns(messaging)

    post :transmit, params: {
      id: @operation.id,
      routes: {
        a.id.to_s => { contact_email: 'a@example.com', phone_number: '0600000001', channel: 'email' },
        b.id.to_s => { contact_email: 'b@example.com', phone_number: '0600000002', channel: 'sms' }
      }
    }
    assert_redirected_to operation_path(@operation)
    assert_equal I18n.t('operations.show.send_success_email_sms', email: 1, sms: 1), flash[:notice]
  end

  test 'transmit persists swapped driver contacts and sends per row channel' do
    @operation.customer.update_columns(enable_email_driver: true, enable_sms_driver: true)
    routes = @operation.operation_routes.planned.where.not(vehicle_id: nil).limit(2).to_a
    skip 'need two vehicle routes' if routes.size < 2
    a, b = routes
    a.update!(vehicle_snapshot: a.vehicle_snapshot.merge('contact_email' => 'a@example.com', 'phone_number' => '0600000001'))
    b.update!(vehicle_snapshot: b.vehicle_snapshot.merge('contact_email' => 'b@example.com', 'phone_number' => '0600000002'))

    messaging = fake_sms_messaging
    Operations::SendDriverSms.stubs(:messaging_service).returns(messaging)

    before = ActionMailer::Base.deliveries.size
    post :transmit, params: {
      id: @operation.id,
      routes: {
        a.id.to_s => { contact_email: 'b@example.com', phone_number: '0600000002', channel: 'email' },
        b.id.to_s => { contact_email: 'a@example.com', phone_number: '0600000001', channel: 'sms' }
      }
    }
    assert_redirected_to operation_path(@operation)
    assert_equal 'b@example.com', a.reload.vehicle_snapshot['contact_email']
    assert_equal '0600000002', a.vehicle_snapshot['phone_number']
    assert_equal 'a@example.com', b.reload.vehicle_snapshot['contact_email']
    assert_equal '0600000001', b.vehicle_snapshot['phone_number']
    sent = ActionMailer::Base.deliveries.drop(before)
    assert_includes sent.flat_map(&:to), 'b@example.com'
    assert_equal 'email', a.last_sent_to
    assert_equal 'sms', b.last_sent_to
  end

  test 'transmit_destinations persists edited contacts on operation stops' do
    @operation.customer.update_columns(enable_email_destination: true, enable_sms_destination: true)
    tracking = @operation.operation_delivery_trackings.first || begin
      OperationDeliveryTracking.ensure_for!(@operation)
      @operation.operation_delivery_trackings.first
    end
    skip 'need a destination tracking' unless tracking
    OperationDeliveryTracking.preload_visit_stops!([tracking])
    stop = tracking.visit_stops.first
    skip 'need a visit stop' unless stop

    before = ActionMailer::Base.deliveries.size
    post :transmit_destinations, params: {
      id: @operation.id,
      trackings: {
        tracking.id.to_s => {
          email: 'nouveau@destinataire.fr',
          phone_number: '0611223344',
          channel: 'email'
        }
      }
    }
    assert_redirected_to operation_path(@operation)
    assert_equal 'nouveau@destinataire.fr', stop.reload.destination_snapshot['email']
    assert_equal '0611223344', stop.destination_snapshot['phone_number']
    sent = ActionMailer::Base.deliveries.drop(before)
    assert_includes sent.flat_map(&:to), 'nouveau@destinataire.fr'
  end

  test 'update changes the operation name' do
    get :show, params: { id: @operation.id }
    assert_includes response.body, 'fa-pencil'
    assert_includes response.body, 'nameInput'
    assert_includes response.body, 'refInput'
    assert_includes response.body, 'd-none'
    @operation.update_columns(status: 'historized')
    patch :update, params: { id: @operation.id, operation: { name: 'Tournée matin' } }
    assert_redirected_to operation_path(@operation)
    assert_equal 'Tournée matin', @operation.reload.name
    patch :update, params: { id: @operation.id, operation: { name: 'Tournée soir' }, format: :json }
    assert_response :success
    assert_equal 'Tournée soir', JSON.parse(response.body)['name']
  end

  test 'update changes the operation ref' do
    patch :update, params: { id: @operation.id, operation: { ref: 'OP-42' }, format: :json }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'OP-42', body['ref']
    assert_equal 'OP-42', @operation.reload.ref

    patch :update, params: { id: @operation.id, operation: { ref: '  ' }, format: :json }
    assert_response :success
    assert_nil JSON.parse(response.body)['ref']
    assert_nil @operation.reload.ref
  end

  test 'update changes the operation date' do
    today = Time.use_zone(users(:user_one).time_zone) { Date.current }
    patch :update, params: { id: @operation.id, operation: { date: today + 1 } }
    assert_redirected_to operation_path(@operation)
    assert_equal today + 1, @operation.reload.date
    patch :update, params: { id: @operation.id, operation: { date: today + 2 }, format: :json }
    assert_response :success
    assert_equal (today + 2).iso8601, JSON.parse(response.body)['date']
  end

  test 'update rejects a date in the past with a json error for the warning toast' do
    original = @operation.date
    past = Time.use_zone(users(:user_one).time_zone) { Date.current - 1 }
    patch :update, params: { id: @operation.id, operation: { date: past }, format: :json }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body['error'], I18n.t('activerecord.errors.models.operation.attributes.date.past')
    assert_equal original, @operation.reload.date
  end

  test 'update rejects a date change once historized' do
    locked_date = Date.new(2026, 9, 1)
    @operation.update_columns(status: 'historized', date: locked_date)
    today = Time.use_zone(users(:user_one).time_zone) { Date.current }
    patch :update, params: { id: @operation.id, operation: { date: today + 1 } }
    assert_redirected_to operation_path(@operation)
    assert_equal locked_date, @operation.reload.date
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
