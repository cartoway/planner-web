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
    Mapotempo::Application.config.geocoder.class.stub_any_instance(:code, lambda{ |*a| raise GeocodeError.new }) do
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

  test 'should upload' do
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join('test/fixtures/files/import_stores_one.csv')),
    })
    file.original_filename = 'import_stores_one.csv'

    import_count = 1

    assert_difference('Store.count', import_count) do
      post :upload_csv, params: { import_csv: { replace: false, file: file } }
    end

    assert_redirected_to stores_path
  end

  test 'should not upload' do
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join('test/fixtures/files/import_invalid.csv')),
    })
    file.original_filename = 'import_invalid.csv'

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
