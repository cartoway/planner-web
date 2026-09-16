require 'test_helper'

class StoresControllerTest < ActionController::TestCase

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @store = stores(:store_one)
    sign_in users(:user_one)
  end

  test 'user can only view stores from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @store
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @store

    get :edit, params: { id: stores(:store_two) }
    assert_response :not_found
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:stores)
    assert_valid response
  end

  test 'index uses v2 when user preference is set' do
    enable_layout_v2!
    get :index
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select '#stores-map-layout[data-controller="v2--stores-index"]', 1
    assert_select %(a[href="#{new_store_path}"][data-turbo-frame="form_sidebar"]), 1
    assert_select '#store_box tr.store-row[data-store-id=?]', @store.id.to_s, 1
    assert_select '#stores-map-layout.destinations-map-layout #map.destinations-map', 1
    assert_select '#store_box thead .stores-list-col--name', 1
    assert_select '.destinations-position-drag-cancel', 1
    config = JSON.parse(css_select('#stores-map-layout').first['data-config'])
    assert config['stores'].any? { |s| s['id'] == @store.id }
  end

  test 'v2 index embeds highlight_store_id in map config when requested' do
    enable_layout_v2!
    get :index, params: { highlight_store_id: @store.id }
    assert_response :success
    config = JSON.parse(css_select('#stores-map-layout').first['data-config'])
    assert_equal @store.id, config['highlight_store_id']
  end

  test 'edit responds with form_sidebar fragment when requested via Turbo Frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @store }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#store-form-sidebar', 1
    assert_select 'form#store-form-sidebar[data-position-editable=true]', 1
    assert_select '[data-v2-map-position-drag-toggle]', 1
    assert_select '#store_reloads [data-v2--nested-fields-target=list] .store-reload-fieldset', minimum: 1
    assert_select '#store_reloads [data-v2--nested-fields-target=list] .accordion-toggle .accordion-chevron', minimum: 1
    assert_select '#store_reloads [data-v2--nested-fields-target=list] .collapse.show', minimum: 1
    assert_select '#store_reloads .collapse.in', 0
    assert_select 'input.store-reload-destroy-flag[name*="[_destroy]"]', minimum: 1
    assert_select '#store_reloads button[data-action*="v2--nested-fields#remove"]', minimum: 1
    assert_select 'template[data-v2--nested-fields-target=template] .store-reload-fieldset', 1
  end

  test 'v2 edit does not invent a store_reload when the store has none' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: stores(:store_one_bis) }
    assert_response :success
    assert_equal 0, stores(:store_one_bis).store_reloads.size
    assert_select '#store_reloads [data-v2--nested-fields-target=list] .store-reload-fieldset', 0
    assert_select 'template[data-v2--nested-fields-target=template] .store-reload-fieldset', 1
  end

  test 'v2 create from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('Store.count') do
      post :create, params: { v2_sidebar: '1', store: { city: @store.city, lat: @store.lat, lng: @store.lng, name: 'v2-store', postalcode: @store.postalcode, street: @store.street, state: @store.state } }
    end
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#store-form-sidebar', 0
    assert_select '[data-v2-saved-id]', 1
  end

  test 'v2 update from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    patch :update, params: { id: @store, v2_sidebar: '1', store: { name: 'v2-updated-store', city: @store.city, lat: @store.lat, lng: @store.lng, postalcode: @store.postalcode, street: @store.street, state: @store.state } }
    assert_response :success
    assert_equal 'v2-updated-store', @store.reload.name
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#store-form-sidebar', 0
    assert_select '[data-v2-saved-id]', 1
  end

  test 'should get one' do
    get :show, params: { id: @store, format: :json }
    assert_response :success
    assert_valid response
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create store' do
    assert_difference('Store.count') do
      post :create, params: { store: { city: @store.city, lat: @store.lat, lng: @store.lng, name: @store.name, postalcode: @store.postalcode, street: @store.street, state: @store.state } }
    end

    assert_redirected_to edit_store_path(assigns(:store))
  end

  test 'should not create store' do
    assert_difference('Store.count', 0) do
      post :create, params: { store: { name: '' } }
    end

    assert_template :new
    store = assigns(:store)
    assert store.errors.any?
    assert_valid response
  end

  test 'should get edit' do
    get :edit, params: { id: @store }
    assert_response :success
    assert_valid response
  end

  test 'should update store' do
    patch :update, params: { id: @store, store: { city: @store.city, lat: @store.lat, lng: @store.lng, name: @store.name, postalcode: @store.postalcode, street: @store.street, state: @store.state } }
    assert_redirected_to edit_store_path(assigns(:store))
  end

  test 'should update store with geocode error' do
    Planner::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
      patch :update, params: { id: @store, store: { city: 'Nantes', lat: nil, lng: nil } }
      assert_redirected_to edit_store_path(assigns(:store))
      assert_not_nil flash[:warning]
    end
  end

  test 'should not update store' do
    patch :update, params: { id: @store, store: { name: '' } }

    assert_template :edit
    store = assigns(:store)
    assert store.errors.any?
    assert_valid response
  end

  test 'should destroy store' do
    vehicle_usage_sets = VehicleUsageSet.where("store_rest_id = #{@store.id} OR store_start_id = #{@store.id} OR store_stop_id = #{@store.id}")
    vehicle_usages = VehicleUsage.where("store_rest_id = #{@store.id} OR store_start_id = #{@store.id} OR store_stop_id = #{@store.id}")

    vehicle_usages.each { |v| assert v.store_start == @store || v.store_stop == @store || v.store_rest == @store }
    vehicle_usage_sets.each { |v| assert v.store_start == @store || v.store_stop == @store || v.store_rest == @store }

    assert_difference('Store.count', -1) do
      delete :destroy, params: { id: @store }
    end

    vehicle_usages.reload
    vehicle_usage_sets.reload

    vehicle_usages.each { |v| assert v.store_start != @store && v.store_stop != @store && v.store_rest != @store }
    vehicle_usage_sets.each { |v| assert v.store_start != @store && v.store_stop != @store && v.store_rest != @store }

    assert_redirected_to stores_path
  end

  test 'should destroy multiple stores' do
    assert_difference('Store.count', -2) do
      delete :destroy_multiple, params: { stores: { stores(:store_one).id => 1, stores(:store_one_bis).id => 1 } }
    end

    assert_redirected_to stores_path
  end

  test 'should show import template' do
    [:csv, :excel].each{ |format|
      get :import_template, params: { format: format }
      assert_response :success
    }
  end

  test 'should import' do
    get :import
    assert_response :success
    assert_valid response
  end

  test 'import uses v2 when user preference is set' do
    enable_layout_v2!
    get :import
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select 'form[action=?]', stores_import_csv_path, 1
    assert_select 'form .offset-md-1.col-md-10', minimum: 1
    assert_select 'form a.btn[href=?]', store_import_template_path(format: :excel), 1
  end

  test 'should upload' do
    file = fixture_file_upload('test/fixtures/files/import_stores_one.csv')

    import_count = 1

    assert_difference('Store.count', import_count) do
      post :upload_csv, params: { import_csv: { replace: false, file: file } }
    end

    assert_redirected_to stores_path
  end

  test 'should not upload' do
    file = fixture_file_upload('test/fixtures/files/import_invalid.csv')

    assert_difference('Store.count', 0) do
      post :upload_csv, params: { import_csv: { replace: false, file: file } }
    end

    assert_template :import
    assert_valid response
  end

  test 'should display application layout on devise scope' do
    get :edit, params: { id: @store }
    assert_template layout: 'application'
  end
end
