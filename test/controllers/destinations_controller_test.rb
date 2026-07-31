require 'test_helper'

class DestinationsControllerTest < ActionController::TestCase
  include DestinationsHelper

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
    enable_destinations_index_v2!
  end

  def enable_destinations_index_v2!(user = users(:user_one))
    user.apply_self_service_display_ui!(
      headers_params: { destinations_index: Preferences::Catalog::Headers::DESTINATIONS_INDEX_V2 }
    )
    user.save!
  end

  def enable_destinations_index_legacy!(user = users(:user_one))
    user.apply_self_service_display_ui!(
      headers_params: { destinations_index: Preferences::Catalog::Headers::DESTINATIONS_INDEX_LEGACY }
    )
    user.save!
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

  test 'index defaults to legacy destinations list' do
    enable_destinations_index_legacy!
    get :index
    assert_response :success
    assert_select '#add', 1
    assert_select '#destinations-map-layout', 0
  end

  test 'index uses v2 when user preference is set' do
    enable_destinations_index_legacy!
    refute users(:user_one).reload.destinations_index_v2?

    enable_destinations_index_v2!
    assert users(:user_one).reload.destinations_index_v2?

    get :index
    assert_response :success
    assert_select '#destinations-map-layout[data-controller="v2--destinations-index"]'
  end

  test 'destinations index preference keeps last value from toggle dual submit' do
    user = users(:user_one)
    user.apply_self_service_display_ui!(headers_params: { destinations_index: %w[legacy v2] })
    user.save!
    assert user.reload.destinations_index_v2?

    user.apply_self_service_display_ui!(headers_params: { destinations_index: Preferences::Catalog::Headers::DESTINATIONS_INDEX_LEGACY })
    user.save!
    refute user.reload.destinations_index_v2?
  end

  test 'v2 index uses saved per_page preference by default' do
    user = users(:user_one)
    user.apply_self_service_display_ui!(
      headers_params: { destinations_index: { version: Preferences::Catalog::Headers::DESTINATIONS_INDEX_V2, per_page: 1 } }
    )
    user.save!

    @request.headers['Turbo-Frame'] = 'destinations_list'
    get :index, params: { page: 1 }

    assert_response :success
    assert_equal 1, assigns(:pagination)[:per_page]
    assert_select 'turbo-frame#destinations_list tbody tr.destination', 1
  end

  test 'v2 index persists per_page preference when changed from params' do
    user = users(:user_one)
    assert_not_equal 50, user.destinations_index_per_page

    @request.headers['Turbo-Frame'] = 'destinations_list'
    get :index, params: { page: 1, per_page: 50 }

    assert_response :success
    assert_equal 50, user.reload.destinations_index_per_page
    assert_equal 50, assigns(:pagination)[:per_page]

    get :index, params: { page: 1 }
    assert_response :success
    assert_equal 50, assigns(:pagination)[:per_page]
  end

  test 'v2 index can change per_page preference more than once' do
    user = users(:user_one)
    user.apply_self_service_display_ui!(
      headers_params: { destinations_index: { version: Preferences::Catalog::Headers::DESTINATIONS_INDEX_V2, per_page: 25 } }
    )
    user.save!

    @request.headers['Turbo-Frame'] = 'destinations_list'
    get :index, params: { page: 1, per_page: 50 }
    assert_response :success
    assert_equal 50, user.reload.destinations_index_per_page
    assert_equal 50, assigns(:pagination)[:per_page]
    assert_select 'a.destinations-per-page-option.active[data-per-page="50"]', 1

    get :index, params: { page: 1, per_page: 100 }
    assert_response :success
    assert_equal 100, user.reload.destinations_index_per_page
    assert_equal 100, assigns(:pagination)[:per_page]
    assert_select 'a.destinations-per-page-option.active[data-per-page="100"]', 1

    get :index, params: { page: 1, per_page: 25 }
    assert_response :success
    assert_equal 25, user.reload.destinations_index_per_page
    assert_equal 25, assigns(:pagination)[:per_page]
    assert_select 'a.destinations-per-page-option.active[data-per-page="25"]', 1
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
    assert_match(/map_layers_title/, response.body)
    assert_match(/geocoder_placeholder/, response.body)
    assert_match(ERB::Util.html_escape(I18n.t('web.geocoder.search')), response.body)
    assert_select 'link[href*="maplibre-gl"]', 1
    assert_select 'script[src*="maplibre-gl"]', 1
    assert_select '.main > .main-primary', 1
    assert_select '.main > .main-primary turbo-frame#main', 1
    assert_select 'aside.form-sidebar.slide-panel--from-right.form-sidebar--collapsed', 1
    assert_select 'aside.form-sidebar turbo-frame#form_sidebar', 1
    assert_select 'button.floating-btn.xl-floating-button.destinations-position-drag-cancel.d-none', 1
  end

  test 'v2 layout menu-left includes extra dashboard when configured' do
    customer = users(:user_one).customer
    @reseller.update!(extra_dashboard_url: 'https://extra.example.com/{LG}/{ID}')

    get :index
    assert_response :success
    expected = "https://extra.example.com/#{I18n.locale}/#{customer.id}"
    assert_select ".menu-left a[href='#{expected}'][target='_blank']", text: I18n.t('customers.menu.extra_analytics')
  end

  test 'v2 index includes vector_style_url in map layers config as-is' do
    layer = users(:user_one).layer
    style_url = 'https://maps.example.com/styles/custom/style.json'
    layer.update!(vector_style_url: style_url)

    get :index
    assert_response :success
    assert_match(%r{maps\.example\.com/styles/custom/style\.json}, response.body)
  end

  test 'v2 index includes overlay vector_style_url in map layers config' do
    customer = users(:user_one).customer
    overlay = Layer.create!(
      source: 'osm',
      name: 'Truck restrictions',
      url: 'https://example.com/truck/{z}/{x}/{y}.png',
      attribution: 'Test',
      overlay: true,
      vector_style_url: 'https://maps.example.com/overlays/truck/style.json'
    )
    customer.profile.layers << overlay

    get :index
    assert_response :success
    assert_match(%r{maps\.example\.com/overlays/truck/style\.json}, response.body)
    assert_match(/&quot;overlay&quot;:true|"overlay":true/, response.body)
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

  test 'v2 index list renders visit subrows when destination has several visits' do
    assert_difference('Visit.count', 1) do
      @request.headers['Turbo-Frame'] = 'form_sidebar'
      post :append_visit, params: { id: @destination.id }
    end
    @request.headers['Turbo-Frame'] = 'destinations_list'
    get :index, params: { per_page: 100, page: 1 }
    assert_response :success
    assert_select %(turbo-frame#destinations_list tbody tr.destination[data-destination-id="#{@destination.id}"]), 2
    assert_select 'turbo-frame#destinations_list tr.destination-visit-subrow', 1
  end

  test 'v2 index list skips visit subrows when no visit-scoped column is active' do
    assert_difference('Visit.count', 1) do
      @request.headers['Turbo-Frame'] = 'form_sidebar'
      post :append_visit, params: { id: @destination.id }
    end
    patch :list_columns, params: { active: %w[name street] }
    assert_response :success
    @request.headers['Turbo-Frame'] = 'destinations_list'
    get :index, params: { per_page: 100, page: 1 }
    assert_response :success
    assert_select %(turbo-frame#destinations_list tbody tr.destination[data-destination-id="#{@destination.id}"]), 1
    assert_select 'turbo-frame#destinations_list tr.destination-visit-subrow', 0
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
    assert_select 'turbo-frame#form_sidebar form[data-turbo-frame="form_sidebar"]', 1
    assert_select 'turbo-frame#form_sidebar .form-submit-bar.is-hidden', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar input[type="submit"]', 0
    assert_select 'turbo-frame#form_sidebar .form-submit-bar button[type="submit"][form="destination-form-sidebar"]', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar[data-tag-entity-create-allowed]', 1
  end

  test 'v2 edit sidebar field labels are bold' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar #destination_city_input label.col-form-label.fw-bold', 1
  end

  test 'v2 edit sidebar geocoding result is display-only, not an editable input' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'input[name="destination[displayed_geocoding_result]"]', 0
    assert_select 'input#displayed-geocoding-result.form-control[disabled][data-displayed-geocoding-result]', 1
    assert_select '#geocoding_result_free.row label.col-form-label.fw-bold[for="displayed-geocoding-result"]', 1
  end

  test 'v2 edit sidebar wires non-blocking geocoding prompt when form is mutable' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select '#destination-details[data-controller~="v2--destination-geocoding"]', 1
    assert_select '#destination-geocode-prompt[data-v2--destination-geocoding-target="prompt"]:not(.d-none)', 1
    assert_select 'button[data-v2--destination-geocoding-target="geocodeButton"][data-action*="v2--destination-geocoding#geocode"]', 1
    assert_select '#destination-details[data-v2--destination-geocoding-confirm-overwrite-point-value]', 1
    assert_select '#destination-geocode-apply.d-none[data-v2--destination-geocoding-target="geocodeApplyPanel"]', 1
    assert_select 'button[data-v2--destination-geocoding-target="geocodeApplyButton"][data-action*="applyGeocodedAddress"]', 1
    assert_select 'input[name="destination[geocode_on_save]"][value=""]', 1
    assert_select 'input[name="destination[geocode_on_save_fingerprint]"][value=""]', 1
    assert_select '#geocoding_result_free[data-v2--destination-geocoding-target="geocodingResultRow"]', 1
  end

  test 'v2 new sidebar wires geocoding prompt on mutable create form' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new
    assert_response :success
    assert_select '#destination-details[data-controller~="v2--destination-geocoding"]', 1
    assert_select '#destination-geocode-prompt[data-v2--destination-geocoding-target="prompt"]:not(.d-none)', 1
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
    # Live header only — another copy lives in template#visits-header-template.
    assert_select '#visits > #visits-header #visits-expand[data-action*="v2--visit-collapses#toggleAll"]', 1
  end

  test 'v2 edit sidebar tags multi-selects use Tom Select Stimulus controller' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    # Destination tags + one persisted visit (+ template copy excluded below).
    assert_select '#destination-details > .destination_visits_attributes_tag_ids_input', 1
    assert_select '#visits > fieldset .destination_visits_attributes_tag_ids_input', 1
    assert_select 'template#visit-fieldset-template .destination_visits_attributes_tag_ids_input', 1
    assert_select '.destination_visits_attributes_tag_ids_input select[data-controller~="v2--tom-select"][name="destination[tag_ids][]"][multiple]', 1
    assert_select '#visits > fieldset select[name^="destination[visits_attributes]"][name$="[tag_ids][]"][multiple][data-controller~="v2--tom-select"]', 1
    assert_select 'select#from_visit_tags[multiple][data-controller~="v2--tom-select"]', 1
    assert_select 'select#to_visit_tags[multiple][data-controller~="v2--tom-select"]', 1
    # destination + visit + 2 bulk selects (+ template visit select is inside <template>)
    assert_select '#destination-details [data-controller~="v2--tom-select"], #visits > fieldset [data-controller~="v2--tom-select"], #from_visit_tags[data-controller~="v2--tom-select"], #to_visit_tags[data-controller~="v2--tom-select"]', 4
  end

  test 'v2 edit sidebar destination and visit tag fields use input-group with trailing tags icon' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select %(turbo-frame#form_sidebar #destination-details .destination_visits_attributes_tag_ids_input .input-group > select[name="destination[tag_ids][]"][multiple]), 1
    assert_select %(turbo-frame#form_sidebar #destination-details .destination_visits_attributes_tag_ids_input .input-group > span.input-group-text), 1
    assert_select %(turbo-frame#form_sidebar #visits > fieldset .destination_visits_attributes_tag_ids_input .input-group > select[multiple][name*="[tag_ids][]"]), 1
    assert_select %(turbo-frame#form_sidebar #visits > fieldset .destination_visits_attributes_tag_ids_input .input-group > span.input-group-text), 1
  end

  test 'v2 edit sidebar visit priority uses Bootstrap native range' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'input#visit_priority_i1.form-range[type="range"][name="destination[visits_attributes][1][priority]"][min="-4"][max="4"][step="1"]', 1
    assert_select '#visits > fieldset .v2-range-output-wrap[data-controller~="v2--range-output"]', 1
  end

  test 'v2 edit sidebar time window bound labels share alignment class' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select '.visit-open-close-input .input-group-text.time-window-bound-label', minimum: 4
  end

  test 'v2 edit sidebar offers direct delete for each persisted visit' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    n = @destination.visits.select(&:persisted?).size
    assert_operator n, :>, 0
    assert_select '#visits > fieldset button[data-controller~="v2--visit-delete"][data-controller~="confirm-click"]', n
    assert_select '#visits > fieldset button[data-controller~="v2--visit-remove"]', 0
    assert_select 'template#visit-fieldset-template button[data-controller~="v2--visit-remove"]', 1
  end

  test 'update nested visit _destroy deletes persisted visit' do
    visit = @destination.visits.first
    assert visit.persisted?
    assert_difference('Visit.count', -1) do
      patch :update, params: {
        id: @destination.id,
        destination: {
          visits_attributes: {
            '0' => { id: visit.id, _destroy: '1' }
          }
        }
      }
    end
    assert_redirected_to edit_destination_path(@destination)
    assert_not Visit.exists?(visit.id)
  end

  test 'v2 visit form renders remove control for unsaved nested visit' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select 'template#visit-fieldset-template button[data-controller~="v2--visit-remove"]', 1
    assert_select 'template#visit-fieldset-template button[data-controller~="v2--visit-delete"]', 0
  end

  test 'new responds with form_sidebar fragment when requested via Turbo Frame' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#destination-form-sidebar.form-horizontal[action*="destinations"]', 1
    assert_select 'turbo-frame#form_sidebar form[data-turbo-frame="form_sidebar"]', 1
    assert_select 'turbo-frame#form_sidebar input[name="v2_sidebar"][value="1"]', 1
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
    assert_select 'button#visit-new[data-action*="v2--visit-new#add"]', 1
    assert_select 'template#visit-fieldset-template', 1
  end

  test 'v2 edit sidebar wires client-side empty visit template' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    first = @destination.visits.first
    first.update!(ref: 'filled-ref', duration: '00:15:00', priority: 3)

    get :edit, params: { id: @destination.id }
    assert_response :success
    assert_select '.destination-visits[data-controller~="v2--visit-new"]', 1
    assert_select 'button#visit-new[data-action*="v2--visit-new#add"]', 1
    assert_select 'template#visit-fieldset-template', 1
    template_html = css_select('#visit-fieldset-template').first.to_s
    assert_includes template_html, 'destination[visits_attributes][0]'
    assert_includes template_html, I18n.t('visits.form.legend', n: 0)
    assert_not_includes template_html, 'filled-ref'
    assert_not_includes template_html, '00:15:00'
    assert_not_includes template_html, 'v2--visit-delete'
    assert_includes template_html, 'v2--visit-remove'
  end

  test 'append_visit appends visit fieldset via turbo stream without replacing sidebar form' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    before = @destination.visits.count
    assert_difference('Visit.count', 1) do
      post :append_visit, params: { id: @destination.id }, as: :turbo_stream
    end
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.media_type
    new_visit = @destination.reload.visits.order(:id).last
    assert_select "turbo-stream[action='append'][target='visits']", 1
    assert_match "visit-fieldset-#{new_visit.id}", response.body
    assert_no_match(/turbo-frame/, response.body)
    assert_equal before + 1, @destination.visits.count
  end

  test 'append_visit prepends visits header via turbo stream when second visit is added' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_equal 1, @destination.visits.count
    post :append_visit, params: { id: @destination.id }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action='prepend'][target='visits']", 1
    assert_match 'visits-header', response.body
  end

  test 'append_visit does not duplicate fields from the previous visit' do
    first = @destination.visits.first
    first.update!(
      ref: 'visit-ref-a',
      duration: '00:15:00',
      time_window_start_1: '08:00:00',
      time_window_end_1: '09:00:00',
      time_window_start_2: '14:00:00',
      time_window_end_2: '15:00:00',
      priority: 3,
      revenue: 42.5,
      force_position: :always_first
    )
    first.tags = [tags(:tag_one), tags(:tag_two)]
    first.save!

    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('Visit.count', 1) do
      post :append_visit, params: { id: @destination.id }, as: :turbo_stream
    end

    new_visit = @destination.reload.visits.order(:id).last
    assert_not_equal first.id, new_visit.id
    assert_nil new_visit.ref
    assert_nil new_visit.duration
    assert_nil new_visit.time_window_start_1
    assert_nil new_visit.time_window_end_1
    assert_nil new_visit.time_window_start_2
    assert_nil new_visit.time_window_end_2
    assert_nil new_visit.priority
    assert_nil new_visit.revenue
    assert_equal 'neutral', new_visit.force_position
    assert_empty new_visit.tags
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
      post :create, params: { v2_sidebar: '1', destination: {
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

  test 'v2 create from sidebar closes form_sidebar with saved destination id' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('Destination.count', 1) do
      post :create, params: { v2_sidebar: '1', destination: {
        city: @destination.city,
        lat: @destination.lat,
        lng: @destination.lng,
        name: 'v2 sidebar create',
        postalcode: @destination.postalcode,
        street: @destination.street,
        state: @destination.state
      } }
    end
    created = assigns(:destination)
    assert_response :success
    assert_select 'turbo-frame#form_sidebar [data-destinations-saved-id=?]', created.id.to_s, 1
    assert_select 'turbo-frame#form_sidebar #destination-form-sidebar', 0
    assert_select 'turbo-frame#form_sidebar .form-sidebar-placeholder', 1
  end

  test 'v2 update from sidebar closes form_sidebar with saved destination id' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    patch :update, params: {
      id: @destination.id,
      v2_sidebar: '1',
      destination: {
        city: @destination.city,
        lat: @destination.lat,
        lng: @destination.lng,
        name: 'v2 sidebar update',
        postalcode: @destination.postalcode,
        street: @destination.street,
        state: @destination.state
      }
    }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar [data-destinations-saved-id=?]', @destination.id.to_s, 1
    assert_select 'turbo-frame#form_sidebar #destination-form-sidebar', 0
    assert_select 'turbo-frame#form_sidebar .form-sidebar-placeholder', 1
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
    assert_select '#search-filters-badges', 1
    assert_select 'turbo-frame#destinations_list tr.destination', assigns(:destinations).size
  end

  test 'v2 index list renders selection checkboxes and destroy controls' do
    get :index
    assert_response :success
    assert_map_config_json_key('can_destroy', true)
    assert_select 'turbo-frame#destinations_list .destinations-toggle-selection', 1
    assert_select 'turbo-frame#destinations_list .destinations-bulk-delete', 1
    assert_select 'turbo-frame#destinations_list .destinations-bulk-delete[data-confirm-click-ready-label-value*="fa-check"]', 1
    assert_select 'turbo-frame#destinations_list tr.destination input[type=checkbox][name^="destinations"]',
                  assigns(:destinations).size
    assert_select 'turbo-frame#destinations_list button.destinations-row-delete',
                  assigns(:destinations).size
    assert_select 'turbo-frame#destinations_list button.destinations-row-delete[data-confirm-click-ready-label-value*="fa-check"]',
                  assigns(:destinations).size
  end

  test 'v2 index list renders sortable column headers' do
    get :index
    assert_response :success
    assert_select 'turbo-frame#destinations_list th.destinations-list-sortable-col a.destinations-list-sort-link', minimum: 1
    assert_select 'turbo-frame#destinations_list a.destinations-list-sort-link[data-turbo-frame="destinations_list"]', minimum: 1
  end

  test 'v2 index list sorts destinations by selected column' do
    destination_a = destinations(:destination_unaffected_one)
    destination_b = destinations(:destination_one)
    destination_a.update_columns(name: 'AAA controller sort')
    destination_b.update_columns(name: 'ZZZ controller sort')

    get :index, params: { sort: 'name', direction: 'asc', per_page: 100 }
    assert_response :success
    ids = css_select('turbo-frame#destinations_list tbody tr.destination').map { |row| row['data-destination-id'].to_i }
    assert_operator ids.index(destination_a.id), :<, ids.index(destination_b.id)
  end

  test 'list_columns persists user column preferences and refreshes list body' do
    @request.headers['Turbo-Frame'] = 'destinations_list_body'
    patch :list_columns, params: { active: %w[name street] }
    assert_response :success
    assert_equal %w[name street], users(:user_one).reload.destinations_list_active_column_ids
    assert_select 'turbo-frame#destinations_list_body thead th', text: I18n.t('display_ui.destinations_list_columns.name')
    assert_select 'turbo-frame#destinations_list_body thead th', text: I18n.t('display_ui.destinations_list_columns.geocoding'), count: 0
    assert_select '.destinations-list-column-selector', count: 0
  end

  test 'list_columns can deactivate all columns' do
    allowed = ::Preferences::Catalog.destinations_list_allowed_column_ids(users(:user_one).customer)
    @request.headers['Turbo-Frame'] = 'destinations_list_body'
    patch :list_columns, params: { active: [], hidden: allowed }
    assert_response :success
    assert_empty users(:user_one).reload.destinations_list_active_column_ids
    assert_select 'turbo-frame#destinations_list_body thead th.destinations-list-col', count: 0
  end

  test 'list_columns can reset to default columns' do
    customer = users(:user_one).customer
    defaults = ::Preferences::Catalog::DestinationsList.default_active_for(customer)
    @request.headers['Turbo-Frame'] = 'destinations_list_body'
    patch :list_columns, params: { active: %w[name comment] }
    assert_response :success
    assert_equal %w[name comment], users(:user_one).reload.destinations_list_active_column_ids

    patch :list_columns, params: { active: defaults }
    assert_response :success
    assert_equal defaults, users(:user_one).reload.destinations_list_active_column_ids
    assert_select 'turbo-frame#destinations_list_body thead th.destinations-list-col', count: defaults.size
  end

  test 'list_columns refreshes table without replacing toolbar dropdown' do
    @request.headers['Turbo-Frame'] = 'destinations_list_body'
    patch :list_columns, params: { active: %w[name city] }
    assert_response :success
    assert_select 'turbo-frame#destinations_list_body', 1
    assert_select 'turbo-frame#destinations_list', count: 0
    assert_select '.destinations-list-column-selector', count: 0
    assert_select '.destinations-bulk-delete', count: 0
    assert_select 'turbo-frame#destinations_list_body tbody', 1
  end

  test 'list_columns selector mirrors route selector structure' do
    get :index
    assert_response :success
    assert_select '.destinations-list-column-selector.searchable-checklist-dropdown', 1
    assert_select '.searchable-checklist-dropdown-search input[type=search]', 1
    assert_select '.searchable-checklist-dropdown-results', 1
    assert_select '.searchable-checklist-dropdown-option--global button[data-action*="resetDefaults"]',
                  text: /#{Regexp.escape(I18n.t('destinations.index.columns_reset_defaults'))}/
    assert_select 'button[data-action*="deactivateAll"]', count: 0
    assert_select '.searchable-checklist-dropdown-option .searchable-checklist-dropdown-checkbox[name="active[]"]', minimum: 1
    assert_select '.searchable-checklist-dropdown-option .form-check', count: 0
    assert_select '.text-muted', text: I18n.t('destinations.index.columns_help', max: Preferences::Catalog::DESTINATIONS_LIST_MAX_ACTIVE), count: 0
    assert_select 'button[data-action*="reverseSelection"]', count: 0
    assert_select 'button[data-action="click->v2--destinations-list-columns#activateAll"]', count: 0
    assert_select 'form[data-turbo-frame="destinations_list_body"]', 1
    assert_select 'turbo-frame#destinations_list turbo-frame#destinations_list_body', 1
    assert_select '.searchable-checklist-dropdown-toggle[data-bs-auto-close="outside"]', 1
    assert_select '[data-controller*="v2--searchable-checklist-dropdown"][data-controller*="v2--destinations-list-columns"]', 1
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

  test 'should show plain text query as removable filter badge' do
    get :index, params: { q: 'Bordeau' }
    assert_response :success
    assert_equal '', assigns(:search_query)
    assert_includes assigns(:active_filters), 'Bordeau'
    assert_select '#search-filters-badges .search-filter-badge[data-filter=?]', 'Bordeau'
    assert_select '#search-query[value=?]', ''
  end

  test 'should filter destinations by plain text filter badge' do
    get :index, params: { filters: ['Bordeau'] }
    assert_response :success
    assert_equal 1, assigns(:destinations).size
    assert_equal 'Bordeau', assigns(:destinations).first.city
    assert_select '#search-filters-badges .search-filter-badge[data-filter=?]', 'Bordeau'
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

  test 'should geocode on save when geocode_on_save flag and fingerprint match' do
    geocode_result = {
      lat: 44.837789,
      lng: -0.579180,
      accuracy: 0.92,
      quality: 'house',
      free: '12 rue des Lilas, 33200 Bordeaux',
      city: 'Bordeaux',
      street: 'Rue des Lilas',
      postcode: '33200',
      geocoder_version: 'test-geocoder',
      geocoded_at: Time.current
    }

    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda { |*_args| geocode_result }) do
      fingerprint = destination_form_address_fingerprint(
        street: @destination.street,
        postalcode: @destination.postalcode,
        city: @destination.city,
        state: @destination.state,
        country: @destination.country
      )

      patch :update, params: {
        id: @destination,
        v2_sidebar: '1',
        destination: {
          name: @destination.name,
          street: @destination.street,
          postalcode: @destination.postalcode,
          city: @destination.city,
          state: @destination.state,
          geocode_on_save: '1',
          geocode_on_save_fingerprint: fingerprint
        }
      }
    end

    assert_response :success
    assert_select 'turbo-frame#form_sidebar [data-destinations-saved-id=?]', @destination.id.to_s, 1
    @destination.reload
    assert_equal '12 rue des Lilas, 33200 Bordeaux', @destination.geocoding_result['free']
    assert_equal 'Bordeaux', @destination.geocoding_result['city']
    assert_equal 'house', @destination.geocoding_level
    assert_in_delta 0.92, @destination.geocoding_accuracy, 0.001
    assert_in_delta 44.837789, @destination.lat, 0.000001
  end

  test 'should ignore client-submitted geocoding_result on save' do
    @destination.update_columns(geocoding_result: { 'free' => 'Previous address' })

    patch :update, params: {
      id: @destination,
      v2_sidebar: '1',
      destination: {
        name: @destination.name,
        street: @destination.street,
        postalcode: @destination.postalcode,
        city: @destination.city,
        lat: 44.837789,
        lng: -0.579180,
        geocoding_accuracy: 0.92,
        geocoding_level: 'house',
        geocoding_result: {
          free: 'Spoofed address',
          city: 'Nantes'
        }.to_json
      }
    }

    assert_response :success
    assert_select 'turbo-frame#form_sidebar [data-destinations-saved-id=?]', @destination.id.to_s, 1
    @destination.reload
    assert_equal 'Previous address', @destination.geocoding_result['free']
    assert_not_equal 'Nantes', @destination.geocoding_result['city']
  end

  test 'should ignore geocode_on_save when fingerprint does not match address' do
    geocode_called = false
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda { |*_args|
      geocode_called = true
      { lat: 1, lng: 1, accuracy: 0.9, quality: 'street', free: 'wrong' }
    }) do
      patch :update, params: {
        id: @destination,
        v2_sidebar: '1',
        destination: {
          name: @destination.name,
          street: @destination.street,
          postalcode: @destination.postalcode,
          city: @destination.city,
          geocode_on_save: '1',
          geocode_on_save_fingerprint: 'stale|fingerprint|mismatch||'
        }
      }
    end

    assert_response :success
    assert_select 'turbo-frame#form_sidebar [data-destinations-saved-id=?]', @destination.id.to_s, 1
    assert_not geocode_called
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
    patch :update, params: { id: @destination, v2_sidebar: '1', destination: { name: '' } }

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
    assert_select '#import_csv_vehicle_usage_set_id'
    assert_select '#import_csv_vehicle_usage_set_id option[value=""]'
    assert_nil assigns(:import_csv).vehicle_usage_set_id
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

  test 'upload_csv without vehicle_usage_set_id creates planning with default vehicle usage set' do
    customer = customers(:customer_one)
    customer.update!(job_destination_geocoding_id: nil)
    Planning.all.each(&:destroy)
    customer.delete_all_destinations
    customer.vehicle_usage_sets.each{ |vus| vus.vehicle_usages.each{ |vu| vu.update!(active: true) } }
    file = fixture_file_upload('test/fixtures/files/import_destinations_single_plan_two_routes.csv')

    assert_difference('Planning.count', 1) do
      post :upload_csv, params: {
        import_csv: {
          replace: false,
          file: file
        }
      }
    end

    assert_equal customer.vehicle_usage_sets.first, customer.plannings.last.vehicle_usage_set
  end

  test 'upload_csv without vehicle_usage_set_id keeps existing planning vehicle usage set' do
    customer = customers(:customer_one)
    customer.update!(job_destination_geocoding_id: nil)
    planning = plannings(:planning_one)
    original_vus_id = planning.vehicle_usage_set_id
    assert_not_equal original_vus_id, vehicle_usage_sets(:vehicle_usage_set_three).id

    file = fixture_file_upload('test/fixtures/files/import_destinations_update_planning_keep_vus.csv')

    post :upload_csv, params: {
      import_csv: {
        replace: false,
        file: file
      }
    }
    assert_valid response
    assert_equal original_vus_id, planning.reload.vehicle_usage_set_id
  end

  test 'upload_csv with vehicle_usage_set_id updates existing planning vehicle usage set' do
    customer = customers(:customer_one)
    customer.update!(job_destination_geocoding_id: nil)
    planning = plannings(:planning_one)
    other_vus = vehicle_usage_sets(:vehicle_usage_set_three)
    assert_not_equal planning.vehicle_usage_set_id, other_vus.id
    other_vus.vehicle_usages.each{ |vu| vu.update!(active: true) }

    file = fixture_file_upload('test/fixtures/files/import_destinations_update_planning_keep_vus.csv')

    post :upload_csv, params: {
      import_csv: {
        replace: false,
        file: file,
        vehicle_usage_set_id: other_vus.id
      }
    }
    assert_valid response
    assert_equal other_vus.id, planning.reload.vehicle_usage_set_id
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
    sync_customer_counters!(customer)
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
