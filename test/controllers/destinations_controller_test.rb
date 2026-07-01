require 'test_helper'

class DestinationsControllerTest < ActionController::TestCase
  # data-config JSON is HTML-escaped in the v2 index (e.g. &quot;key&quot;:value).
  def assert_map_config_json_key(key, value = nil)
    if value.nil?
      assert(
        response.body.include?("\"#{key}\":") || response.body.include?("&quot;#{key}&quot;:"),
        "Expected map config to include #{key}"
      )
    else
      raw = "\"#{key}\":#{value.is_a?(String) ? %("#{value}") : value}"
      escaped = "&quot;#{key}&quot;:#{value.is_a?(String) ? %(&quot;#{value}&quot;) : value}"
      assert(
        response.body.include?(raw) || response.body.include?(escaped),
        "Expected map config to include #{raw}"
      )
    end
  end

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @destination = destinations(:destination_one)
    sign_in users(:user_one)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  test 'user can only view destinations from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @destination
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @destination

    get :edit, params: { id: destinations(:destination_four) }
    assert_response :not_found
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:destinations)
    assert_not_nil assigns(:pagination)
    assert_not_nil assigns(:total_count)
    assert_valid response
    # V2 destinations index: full-page map + sidebar list
    assert_select '#map'
    assert_select '#destinations-map-layout[data-controller="v2--destinations-index"]'
    assert_select 'script[type="importmap"]', 1
    assert_match(/map_overlay_title/, response.body)
    assert_select 'link[href*="maplibre-gl"]', 1
    assert_select 'script[src*="maplibre-gl"]', 1
    assert_select '.main > .main-primary', 1
    assert_select '.main > .main-primary turbo-frame#main', 1
    assert_select 'aside.form-sidebar.slide-panel--from-right.form-sidebar--collapsed', 1
    assert_select 'aside.form-sidebar turbo-frame#form_sidebar', 1
    assert_select 'button.floating-btn.xl-floating-button.destinations-position-drag-cancel.d-none', 1
  end

  test 'v2 index exposes map geojson url in config instead of inline destinations' do
    get :index
    assert_response :success
    assert_map_config_json_key('map_geojson_url')
    assert_not response.body.include?('"destinations":[')
  end

  test 'map returns geojson for filtered scope' do
    get :map, params: { per_page: 25 }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'FeatureCollection', body['type']
    assert body['features'].is_a?(Array)
  end

  test 'map bounds_only returns bounds without loading all features' do
    get :map, params: { bounds_only: true }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body['features']
    assert body['bounds'].present?
  end

  test 'map respects bbox filter' do
    get :map, params: { bbox: '-1,48,3,50', per_page: 25 }
    assert_response :success
    body = JSON.parse(response.body)
    body['features'].each do |f|
      lng, lat = f['geometry']['coordinates']
      assert lat.between?(48, 50)
      assert lng.between?(-1, 3)
    end
  end

  test 'v2 index embeds highlight_destination_id in map config when requested' do
    get :index, params: { highlight_destination_id: @destination.id }
    assert_response :success
    assert_map_config_json_key('highlight_destination_id', @destination.id)
  end

  test 'v2 index paginated list renders only turbo-frame when Turbo-Frame requests destinations_list' do
    @request.headers['Turbo-Frame'] = 'destinations_list'
    get :index, params: { per_page: 1, page: 1 }
    assert_response :success
    assert_select 'turbo-frame#destinations_list', 1
    assert_select 'turbo-frame#destinations_list tbody tr.destination', 1
    assert_select '#destinations-map-layout', 0
  end

  test 'v2 index edit links target form_sidebar turbo frame' do
    get :index
    assert_response :success
    assert_select %(a[href="#{edit_destination_path(@destination)}"][data-turbo-frame="form_sidebar"][data-turbo-prefetch="false"]), 1
  end

  test 'v2 index new link targets form_sidebar turbo frame' do
    get :index
    assert_response :success
    assert_select %(a[href="#{new_destination_path}"][data-turbo-frame="form_sidebar"][data-turbo-prefetch="false"]), 1
  end

  test 'edit responds with form_sidebar fragment when requested via Turbo Frame' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar.form-horizontal[action*="destination"]', 1
    assert_select 'turbo-frame#form_sidebar form[data-turbo-frame="_top"]', 1
    assert_select 'turbo-frame#form_sidebar .form-submit-bar.is-hidden', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar input[type="submit"]', 0
    assert_select 'turbo-frame#form_sidebar .form-submit-bar button[type="submit"][form="destination-form-sidebar"]', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar[data-tag-entity-create-allowed]', 1
  end

  test 'v2 edit sidebar visits list wires visit-collapses controller on #visits' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar #visits[data-controller~="v2--visit-collapses"]', 1
  end

  test 'v2 edit sidebar collapse-all button uses visit-collapses when several visits' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('Visit.count', 1) do
      post :append_visit, params: { id: @destination.id }
    end
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_operator @destination.reload.visits.size, :>, 1
    assert_select '#visits-expand[data-action*="v2--visit-collapses#toggleAll"]', 1
  end

  test 'v2 edit sidebar tags multi-selects use Tom Select Stimulus controller' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select '.destination_visits_attributes_tag_ids_input', 2
    assert_select '.destination_visits_attributes_tag_ids_input select[data-controller~="v2--tom-select"][name="destination[tag_ids][]"][multiple]', 1
    assert_select 'select[name^="destination[visits_attributes]"][name$="[tag_ids][]"][multiple][data-controller~="v2--tom-select"]', 1
    assert_select 'select#from_visit_tags[multiple][data-controller~="v2--tom-select"]', 1
    assert_select 'select#to_visit_tags[multiple][data-controller~="v2--tom-select"]', 1
    # destination_one has one visit → 2 Tom hosts (destination + visit) + 2 bulk selects in modal
    assert_select '[data-controller~="v2--tom-select"]', 4
  end

  test 'v2 edit sidebar destination and visit tag fields use input-group with trailing tags icon' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select %(turbo-frame#form_sidebar #destination-details .destination_visits_attributes_tag_ids_input .input-group > select[name="destination[tag_ids][]"][multiple]), 1
    assert_select %(turbo-frame#form_sidebar #destination-details .destination_visits_attributes_tag_ids_input .input-group > span.input-group-text), 1
    assert_select %(turbo-frame#form_sidebar #visits .destination_visits_attributes_tag_ids_input .input-group > select[multiple][name*="[tag_ids][]"]), 1
    assert_select %(turbo-frame#form_sidebar #visits .destination_visits_attributes_tag_ids_input .input-group > span.input-group-text), 1
  end

  test 'v2 edit sidebar visit priority uses Bootstrap native range' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'input#visit_priority_i1.form-range[type="range"][name="destination[visits_attributes][1][priority]"][min="-4"][max="4"][step="1"]', 1
    assert_select '.v2-range-output-wrap[data-controller~="v2--range-output"]', 1
  end

  test 'v2 edit sidebar offers direct delete for each persisted visit' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    n = @destination.visits.select(&:persisted?).size
    assert_operator n, :>, 0
    assert_select 'button[data-controller="v2--visit-delete"]', n
  end

  test 'new responds with form_sidebar fragment when requested via Turbo Frame' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar.form-horizontal[action*="destinations"]', 1
    assert_select 'turbo-frame#form_sidebar form[data-turbo-frame="form_sidebar"]', 1
    assert_select 'turbo-frame#form_sidebar .form-submit-bar.is-hidden', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar input[type="submit"]', 0
    assert_select 'turbo-frame#form_sidebar .form-submit-bar button[type="submit"][form="destination-form-sidebar"]', 1
  end

  test 'v2 new destination sidebar has no visit fieldsets and no hidden visit template' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new
    assert_response :success
    assert_select '#visits > fieldset', 0
    assert_select '#visit-fieldset-template', 0
  end

  test 'append_visit creates a persisted visit and re-renders form_sidebar' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    before = @destination.visits.count
    assert_difference('Visit.count', 1) do
      post :append_visit, params: { id: @destination.id }
    end
    assert_response :success
    assert_equal before + 1, @destination.reload.visits.count
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select '#visits fieldset.visit-fieldset', before + 1
    assert_select %(a#visit-new[href="#{append_visit_destination_path(@destination)}"][data-turbo-method="post"]), 1
  end

  test 'append_visit creates first visit when destination has none' do
    dest = customers(:customer_one).destinations.create!(
      name: 'solo_dest',
      street: 'Rue X',
      postalcode: '33000',
      city: 'Testville',
      lat: 44.8,
      lng: -0.6
    )
    assert_equal 0, dest.visits.count
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('Visit.count', 1) do
      post :append_visit, params: { id: dest.id }
    end
    assert_response :success
    assert_equal 1, dest.reload.visits.count
  end

  test 'create with validation errors renders new_sidebar when requested via Turbo Frame' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_no_difference('Destination.count') do
      post :create, params: { destination: {
        name: '',
        city: @destination.city,
        postalcode: @destination.postalcode,
        street: @destination.street
      } }
    end
    assert_response :unprocessable_entity
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form[data-turbo-frame="form_sidebar"]', 1
  end

  test 'v2 edit sidebar shows map position hint and no embedded Leaflet map' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar .v2-destination-map-position-hint', 1
    assert_select 'turbo-frame#form_sidebar #map.map-fixed-size', 0
    lat = css_select('turbo-frame#form_sidebar input#destination_lat').first
    lng = css_select('turbo-frame#form_sidebar input#destination_lng').first
    assert lat, 'expected destination lat input in form sidebar'
    assert lng, 'expected destination lng input in form sidebar'
    assert_in_delta 0.000001, lat['step'].to_f, 1e-12
    assert_in_delta 0.000001, lng['step'].to_f, 1e-12
    assert_select 'turbo-frame#form_sidebar button[data-v2-map-position-drag-toggle]', 1
  end

  test 'index renders v2 list and search when destinations exist' do
    get :index
    assert_response :success
    assert_select '#destinations-search-form'
    assert_select '#search-query[role="combobox"]', 1
    assert_select '#search-query-dropdown [data-search-key]', DestinationSearchParser::ALLOWED_KEYS.size
    assert_select 'turbo-frame#destinations_list tr.destination', assigns(:destinations).size
  end

  test 'v2 index list renders selection checkboxes and destroy controls' do
    get :index
    assert_response :success
    assert_map_config_json_key('can_destroy', true)
    assert_select 'turbo-frame#destinations_list .destinations-toggle-selection', 1
    assert_select 'turbo-frame#destinations_list .destinations-bulk-delete', 1
    assert_select 'turbo-frame#destinations_list tr.destination input[type=checkbox][name^="destinations"]',
                  assigns(:destinations).size
    assert_select 'turbo-frame#destinations_list button.destinations-row-delete',
                  assigns(:destinations).size
  end

  test 'list_columns persists user column preferences and refreshes list' do
    patch :list_columns, params: { active: %w[name address] }
    assert_response :success
    assert_equal %w[name address], users(:user_one).reload.destinations_list_active_column_ids
    assert_select 'turbo-frame#destinations_list thead th', text: I18n.t('display_ui.destinations_list_columns.name')
    assert_select 'turbo-frame#destinations_list thead th', text: I18n.t('display_ui.destinations_list_columns.geocoding'), count: 0
    assert_select '#destinations-list-col-geocoding', 1
  end

  test 'should filter destinations by key value search' do
    get :index, params: { q: 'city:Bordeau' }
    assert_response :success
    assert_equal 1, assigns(:destinations).size
    assert_equal 'Bordeau', assigns(:destinations).first.city
  end

  test 'should filter destinations by filter badges' do
    get :index, params: { filters: ['name:destination_one'] }
    assert_response :success
    assert_equal 1, assigns(:destinations).size
    assert_equal 'destination_one', assigns(:destinations).first.name
  end

  test 'should filter destinations by filter badge with spaces in value' do
    destination = destinations(:destination_one)
    destination.update!(name: 'Jean Dupont')

    get :index, params: { filters: ['name:Jean Dupont'] }
    assert_response :success
    assert_equal 1, assigns(:destinations).size
    assert_equal 'Jean Dupont', assigns(:destinations).first.name
  end

  test 'should combine filters and live query' do
    get :index, params: { filters: ['city:Bordeau'], q: 'name:destination' }
    assert_response :success
    assert_equal 1, assigns(:destinations).size
    assert_equal 'destination_one', assigns(:destinations).first.name
  end

  test 'should get index in excel' do
    customers(:customer_one).update enable_orders: false
    visits(:visit_one).update deliveries: {2 => 2.5}
    get :index, params: { format: :excel }
    assert_response :success
    assert_not_nil assigns(:destinations)
    assert_equal "b;destination_one;Rue des Lilas;MyString;33200;Bordeau;;49.1857;-0.3735;;;;MyString;MyString;\"\";;\"\";b;00:05:33;10:00;11:00;;;4;;tag1;neutre;;2.5;;\r".encode("iso-8859-1"), response.body.split("\n").find{ |l| l.start_with? 'b;destination_one' }
  end

  test 'should get index in excel with order array' do
    get :index, params: { format: :excel }
    assert_response :success
    assert_not_nil assigns(:destinations)
    assert_equal "b;destination_one;Rue des Lilas;MyString;33200;Bordeau;;49.1857;-0.3735;;;;MyString;MyString;\"\";;\"\";b;00:05:33;10:00;11:00;;;4;;tag1;neutre\r".encode("iso-8859-1"), response.body.split("\n").find{ |l| l.start_with? 'b;destination_one' }
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create destination without visit' do
    assert_no_difference('Stop.count') do
      assert_difference('Destination.count') do
        assert_no_difference('Visit.count') do
          post :create, params: { destination: {
            city: @destination.city,
            lat: @destination.lat,
            lng: @destination.lng,
            name: @destination.name,
            postalcode: @destination.postalcode,
            street: @destination.street,
            state: @destination.state,
            detail: @destination.detail,
            comment: @destination.comment,
            phone_number: @destination.phone_number
          } }
        end
      end
    end

    assert_redirected_to edit_destination_path(assigns(:destination))
  end

  test 'should create destination with visit' do
    assert_difference('Stop.count', 1) do
      assert_difference('Destination.count', 1) do
        assert_difference('Visit.count', 1) do
          post :create, params: { destination: {
            city: 'Bordeaux',
            name: 'new dest',
            postalcode: '33000',
            state: 'Aquitaine',
            comment: 'comment',
            phone_number: '+336123456789',
            visits_attributes: [{
              time_window_start_1: '10:00',
              time_window_end_1: '18:00',
              time_window_start_2: '20:00',
              time_window_end_2: '21:00',
              priority: -4,
              quantity1_1: '10',
              tag_ids: [tags(:tag_one).id]
            }]
          } }
        end
      end
    end

    assert_redirected_to edit_destination_path(assigns(:destination))
  end

  test 'should create destination with visit exceeding one day' do
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        post :create, params: { destination: {
            city: 'Bordeaux',
            name: 'new dest',
            postalcode: '33000',
            state: 'Aquitaine',
            comment: 'comment',
            phone_number: '+336123456789',
            visits_attributes: {'1' => {
                time_window_start_1: '18:00',
                time_window_end_1: '06:00',
                time_window_end_1_day: '1',
                time_window_start_2: '10:00',
                time_window_start_2_day: '1',
                time_window_end_2: '14:00',
                time_window_end_2_day: '1'
            }}
        } }
      end
    end
    assert_redirected_to edit_destination_path(assigns(:destination))

    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        post :create, params: { destination: {
            city: 'Bordeaux',
            name: 'new dest',
            postalcode: '33000',
            state: 'Aquitaine',
            comment: 'comment',
            phone_number: '+336123456789',
            visits_attributes: [{
                                    time_window_start_1: '18:00',
                                    time_window_end_1: '06:00',
                                    time_window_end_1_day: '1',
                                    time_window_start_2: '10:00',
                                    time_window_start_2_day: '1',
                                    time_window_end_2: '14:00',
                                    time_window_end_2_day: '1'
                                }]
        } }
      end
    end
    assert_redirected_to edit_destination_path(assigns(:destination))
  end

  test 'should create destination and touch planning' do
    d = Planning.find_by(name: 'planning1')
    d.tags = []
    d.save!
    assert_difference('Stop.count', 1) do
      assert_difference('Destination.count', 1) do
        assert_difference('Visit.count', 1) do
          post :create, params: { destination: {
            city: 'Bordeaux',
            name: 'new dest',
            postalcode: '33000',
            comment: 'comment',
            phone_number: '+336123456789',
            visits_attributes: [{
              time_window_start_1: '10:00',
              time_window_end_1: '18:00',
              time_window_start_2: '20:00',
              time_window_end_2: '21:00',
              priority: -4,
              quantity1_1: '10'
            }]
          } }
        end
      end
    end

    assert_redirected_to edit_destination_path(assigns(:destination))
  end

  test 'should not create destination' do
    assert_difference('Destination.count', 0) do
      post :create, params: { destination: { name: '' } }
    end

    assert_template :new
    destination = assigns(:destination)
    assert destination.errors.any?
    assert_valid response
  end

  test 'should get edit' do
    get :edit, params: { id: @destination }
    assert_response :success
    assert_valid response
  end

  test 'should update destination' do
    patch :update, params: { id: @destination, destination: { city: @destination.city, lat: @destination.lat, lng: @destination.lng, name: @destination.name, postalcode: @destination.postalcode, street: @destination.street, state: @destination.state, detail: @destination.detail, comment: @destination.comment, phone_number: @destination.phone_number } }
    assert_redirected_to edit_destination_path(assigns(:destination))
  end

  test 'should update destination and visit' do
    size_visits = @destination.visits.size
    visits_attributes = Hash[@destination.visits.map{ |v| [v.id.to_s, v.attributes.merge('deliveries' => {'1' => 1, '2' => 2.3})]}]
    patch :update, params: { id: @destination, destination: { visits_attributes: visits_attributes} }
    assert_redirected_to edit_destination_path(assigns(:destination))
    assert_equal [[1, 2.3]] * size_visits, @destination.reload.visits.map{ |v| v.deliveries.values }
  end

  test 'should update destination with geocode error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      patch :update, params: { id: @destination, destination: { city: 'Nantes', lat: nil, lng: nil } }
      assert_redirected_to edit_destination_path(assigns(:destination))
      assert_not_nil flash[:warning]
    end
  end

  test 'should update destination tags' do
    patch :update, params: { id: @destination, destination: { tag_ids: [tags(:tag_two).id] } }
    assert_redirected_to edit_destination_path(assigns(:destination))
  end

  test 'should not update destination' do
    patch :update, params: { id: @destination, destination: { name: '' } }

    assert_template :edit
    destination = assigns(:destination)
    assert destination.errors.any?
    assert_valid response
  end

  test 'should not update destination in form_sidebar turbo frame' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    patch :update, params: { id: @destination, destination: { name: '' } }

    assert_response :unprocessable_entity
    assert_select 'turbo-frame#form_sidebar', 1
    assert assigns(:destination).errors.any?
    assert_valid response
  end

  test 'should destroy destination' do
    assert_difference('Destination.count', -1) do
      delete :destroy, params: { id: @destination }
    end

    assert_redirected_to destinations_path
  end

  test 'should clear' do
    delete :clear
    assert_redirected_to destinations_path
  end

  test 'should show import template' do
    [:csv, :excel].each{ |format|
      get :import_template, format: format
      assert_response :success
    }
  end

  test 'should import with custom columns headers' do
    options = { import: { destinations: { spreadsheetColumnsDef: { route: 'my_route' } } } }
    users(:user_one).customer.update advanced_options: options
    get :import
    assert_response :success
    assert_valid response
    assert_equal 'my_route', assigns(:columns_default)['route']
  end

  test 'should upload' do
    customers(:customer_one).update(job_destination_geocoding_id: nil)
    file = fixture_file_upload('test/fixtures/files/import_destinations_one.csv')
    destinations_count = @destination.customer.destinations.count
    plannings_count = @destination.customer.plannings.select{ |planning| planning.tags_compatible? [tags(:tag_one)] }.count
    import_count = 1
    import_rest_count = @destination.customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.active && v.rest_duration && v.rest_start && v.rest_stop }.size
    # Adds 1 destination, adds it to each existing plan and creates one extra plan with existing destinations
    assert_difference('Destination.count', import_count) do
      assert_difference('Stop.count', (destinations_count + import_rest_count) + import_count * (plannings_count + 1)) do
        assert_difference('Planning.count', 1) do
          post :upload_csv, params: { import_csv: { replace: false, file: file } }
          assert_valid response
        end
      end
    end

    assert_redirected_to edit_planning_url(Planning.last)
  end

  test 'import shows vehicle usage set select when customer has several configurations' do
    assert_operator customers(:customer_one).vehicle_usage_sets.count, :>, 1
    get :import
    assert_response :success
    assert_match(/import_csv_vehicle_usage_set_id|vehicle_usage_set_id/, response.body)
    assert_equal customers(:customer_one).vehicle_usage_sets.pick(:id), assigns(:import_csv).vehicle_usage_set_id
  end

  test 'upload_csv uses vehicle usage set from form when csv has no column' do
    customer = customers(:customer_one)
    customer.update!(job_destination_geocoding_id: nil)
    Planning.all.each(&:destroy)
    customer.delete_all_destinations
    customer.vehicle_usage_sets.each{ |vus| vus.vehicle_usages.each{ |vu| vu.update!(active: true) } }
    file = fixture_file_upload('test/fixtures/files/import_destinations_single_plan_two_routes.csv')

    assert_difference('Planning.count', 1) do
      post :upload_csv, params: {
        import_csv: {
          replace: true,
          file: file,
          vehicle_usage_set_id: vehicle_usage_sets(:vehicle_usage_set_three).id
        }
      }
    end

    assert_equal vehicle_usage_sets(:vehicle_usage_set_three), customer.plannings.last.vehicle_usage_set
  end

  test 'should not upload' do
    file = fixture_file_upload('test/fixtures/files/import_invalid.csv')
    assert_difference('Destination.count', 0) do
      post :upload_csv, params: { import_csv: { replace: false, file: file } }
    end

    assert_template :import
    assert_valid response
  end

  test 'should display an error' do
    file = fixture_file_upload('import_malformed.csv', 'text/csv')

    assert_difference('Destination.count', 0) do
      post :upload_csv, params: { import_csv: { replace: false, file: file } }
    end

    assert_template :import
    assert_valid response
  end

  test 'should redirect after upload_csv without geocoding job' do
    customers(:customer_one).update(job_destination_geocoding_id: nil)
    [
      { redirect: 'last_planning', file: 'import_custom_destinations_one.csv', column_def: { route: 'tour' } },
      { redirect: 'destinations', file: 'import_destinations_update.csv', column_def: nil },
      { redirect: 'plannings', file: 'import_destinations_several_plans.csv', column_def: nil }
    ].each do |test|
      file = fixture_file_upload("test/fixtures/files/#{test[:file]}")
      post :upload_csv, params: { import_csv: { replace: false, file: file, column_def: test[:column_def] ? test[:column_def] : nil } }

      case test[:redirect]
      when 'last_planning'
        assert_redirected_to edit_planning_url(Planning.last)
      when 'destinations'
        assert_redirected_to destinations_url
      when 'plannings'
        assert_redirected_to plannings_url
      end
    end
  end

  test 'should redirect after upload_csv with geocoding job' do
    [
      { redirect: 'destinations', file: 'import_custom_destinations_one.csv', column_def: { route: 'tour' } },
      { redirect: 'destinations', file: 'import_destinations_update.csv', column_def: nil },
      { redirect: 'destinations', file: 'import_destinations_several_plans.csv', column_def: nil }
    ].each do |test|
      file = fixture_file_upload("test/fixtures/files/#{test[:file]}")
      post :upload_csv, params: { import_csv: { replace: false, file: file, column_def: test[:column_def] ? test[:column_def] : nil } }

      assert_redirected_to destinations_url
    end
  end

  test 'should use limitation' do
    customer = @destination.customer
    customer.delete_all_destinations
    customer.max_destinations = 1
    customer.save!

    assert_difference('Destination.count', 1) do
      post :create, params: { destination: {
        city: 'Bordeaux',
        name: 'new dest',
        postalcode: '33000',
        state: 'Aquitaine',
        comment: 'comment',
        phone_number: '+336123456789',
        visits_attributes: [{
          time_window_start_1: '10:00',
          time_window_end_1: '18:00',
          time_window_start_2: '20:00',
          time_window_end_2: '21:00',
          quantity1_1: '10',
          tag_ids: [tags(:tag_one).id]
        }]
      } }
    end

    assert_difference('Destination.count', 0) do
      assert_difference('Visit.count', 0) do
        post :create, params: { destination: {
          city: 'B2',
          name: 'new 2',
          postalcode: '33000',
          state: 'Aquitaine',
          comment: 'comment',
          phone_number: '+336123456789',
          visits_attributes: [{
            time_window_start_1: '10:00',
            time_window_end_1: '18:00',
            time_window_start_2: '20:00',
            time_window_end_2: '21:00',
            quantity1_1: '10',
            tag_ids: [tags(:tag_one).id]
          }]
        } }
      end
    end
  end

  test 'should update tag to move stop from plan to other' do
    without_loading Stop, if: -> (obj) { obj.route_id != routes(:route_zero_one).id && obj.route_id != routes(:route_zero_two).id } do
      patch :update, params: { id: destinations(:destination_unaffected_one), destination: {
        tag_ids: [],
        visits_attributes: [{
          tag_ids: [tags(:tag_two).id]
        }]
      } }
      assert_redirected_to edit_destination_path(assigns(:destination))
    end
  end

  test 'import disables file field when destination form is read-only' do
    return unless Role.column_names.include?('forms')

    user = users(:user_one)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "import-ro-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(
        'destination' => { 'visible' => true, 'usable' => false }
      )
    )
    user.update!(role_id: role.id)
    sign_in user

    get :import
    assert_response :success
    assert_select 'fieldset[disabled] input[type=file]'
  ensure
    user.update!(role_id: nil) if user.reload.role_id.present?
    role&.destroy
    sign_in users(:user_one)
  end

  test 'upload_csv returns forbidden when destination form is read-only' do
    return unless Role.column_names.include?('forms')

    user = users(:user_one)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "upload-ro-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(
        'destination' => { 'visible' => true, 'usable' => false }
      )
    )
    user.update!(role_id: role.id)
    sign_in user

    file = fixture_file_upload('test/fixtures/files/import_destinations_one.csv', 'text/csv')
    post :upload_csv, params: { import_csv: { replace: false, file: file } }
    assert_response :forbidden
  ensure
    user.update!(role_id: nil) if user.reload.role_id.present?
    role&.destroy
    sign_in users(:user_one)
  end

  test 'index disables new destination button when destination form is read-only' do
    return unless Role.column_names.include?('forms')

    user = users(:user_one)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "index-ro-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(
        'destination' => { 'visible' => true, 'usable' => false }
      )
    )
    user.update!(role_id: role.id)
    sign_in user

    get :index
    assert_response :success
    assert_match(/id="add"[^>]*disabled/, response.body)
    assert_match(/"can_create":false/, response.body)
  ensure
    user.update!(role_id: nil) if user.reload.role_id.present?
    role&.destroy
    sign_in users(:user_one)
  end

  test 'clear returns forbidden when destination form is read-only' do
    return unless Role.column_names.include?('forms')

    user = users(:user_one)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "clear-ro-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(
        'destination' => { 'visible' => true, 'usable' => false }
      )
    )
    user.update!(role_id: role.id)

    delete :clear

    assert_response :forbidden
  ensure
    user.update!(role_id: nil) if user.reload.role_id.present?
  end
end
