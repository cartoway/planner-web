require 'test_helper'

class VehicleUsageSetsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
    sign_in users(:user_one)
    assert_valid response
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect { |i| [1000, 60, '_ibE_seK_seK_seK'] } }) do
      yield
    end
  end

  test 'user can only view vehicle_usage_sets from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :edit, @vehicle_usage_set
    assert ability.can? :update, @vehicle_usage_set
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @vehicle_usage_set

    get :edit, params: { id: vehicle_usage_sets(:vehicle_usage_set_two) }
    assert_response :not_found
  end

  test 'vehicle_usage_sets are forbidden when forms vehicle_usages is hidden' do
    u = users(:user_one)
    forms = Preferences::Catalog.default_forms.merge('vehicle_usages' => { 'visible' => false, 'usable' => false })
    role = Role.create!(
      reseller: @reseller,
      name: "no-vus-forms-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
    )
    u.update!(role_id: role.id)

    assert_not u.reload.form_visible?(:vehicle_usages)
    ability = Ability.new(u)
    assert ability.cannot? :manage, @vehicle_usage_set

    sign_in u
    get :index
    assert_response :redirect
    assert_redirected_to root_url
  end

  test 'should get index vehicle_usage_set' do
    get :index
    assert_response :success
    assert_not_nil assigns(:vehicle_usage_sets)
    assert_valid response
  end

  test 'index uses v2 when user preference is set' do
    enable_layout_v2!
    get :index
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select 'a[data-turbo-frame=form_sidebar][href=?]', edit_vehicle_usage_set_path(@vehicle_usage_set, back: true)
    assert_select '.vehicle-usage-sets-index', 1
    assert_select 'table#accordion-vehicle-usage-sets', 1
    assert_select 'table#accordion-vehicle-usage-sets tr.usage-set-heading--stripe', minimum: 1
    assert_select 'table#accordion-vehicle-usage-sets tr.usage-set-heading', minimum: 1
    assert_select 'table#accordion-vehicle-usage-sets tr.vehicle_usages table.vehicle-usages-table', minimum: 1
    assert_select 'table.vehicle-usages-table span.default-color', minimum: 1
    assert_select 'table#accordion-vehicle-usage-sets tr.usage-set-heading > td.text-end > .btn-group', minimum: 1
    assert_select 'table.vehicle-usages-table td.text-end > .btn-group', minimum: 1
    assert_select 'button.usage-set-toggle i.usage-set-chevron.fa-chevron-right', minimum: 1
    first_set = assigns(:vehicle_usage_sets).first
    assert_select "button.usage-set-toggle[data-bs-target='#collapseUsageSet#{first_set.id}']:not(.collapsed)[aria-expanded=true]", 1
    assert_select "#collapseUsageSet#{first_set.id}.show", 1
    assert_select 'table#accordion-vehicle-usage-sets .collapse.show', 1
    assert_select '.collapse[data-bs-parent="#accordion-vehicle-usage-sets"]', minimum: 2
    assert_select 'td.vehicle-usage-sort-handle[data-action*="pointerDown"]', minimum: 1
    assert_select '.accordion-item', 0
    [
      destinations_path,
      vehicle_usage_sets_path,
      import_vehicle_usage_sets_path,
      deliverable_units_path,
      stores_path,
      store_import_path
    ].each do |href|
      assert_select 'a[href=?][data-turbo-frame=main][data-turbo-action=advance]', href
    end
  end

  test 'edit responds with form_sidebar fragment when requested via Turbo Frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @vehicle_usage_set }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#vehicle-usage-set-form-sidebar', 1
    assert_select 'turbo-frame#form_sidebar .form-submit-bar button[type=submit][form=vehicle-usage-set-form-sidebar]', 1
    assert_select 'form#vehicle-usage-set-form-sidebar input[name="v2_sidebar"][value="1"]', 1
    assert_select 'form#vehicle-usage-set-form-sidebar .input-group-text', minimum: 1
    assert_select 'form#vehicle-usage-set-form-sidebar .input-group-addon', 0
    assert_select 'form#vehicle-usage-set-form-sidebar .offset-md-1', minimum: 1
    assert_select '#vehicle_usage_set_time_window_start_time_window_end_input.fleet-split .input-group', 2
    assert_select '#vehicle_usage_set_time_window_start_time_window_end_input .fleet-bound-label', 2
    assert_select 'form#vehicle-usage-set-form-sidebar[data-controller~="v2--rest-type-fields"]', 1
    assert_select 'form#vehicle-usage-set-form-sidebar[data-action*="v2--rest-type-fields#change"]', 1
    assert_select 'input[type=radio][name="vehicle_usage_set[rest_mode]"]', 2
  end

  test 'edit sidebar store reloads is a tom-select multi-select' do
    enable_layout_v2!
    @vehicle_usage_set.customer.update!(enable_store_stops: true)
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @vehicle_usage_set }
    assert_response :success
    assert_select 'select#vehicle_usage_set_store_reload_ids[multiple][data-controller~="v2--tom-select"]', 1
    assert_select 'select#vehicle_usage_set_store_reload_ids[data-v2--tom-select-simple-value="true"]', 1
    assert_select 'select#vehicle_usage_set_store_reload_ids option', minimum: 1
  end

  test 'v2 create from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('VehicleUsageSet.count') do
      post :create, params: { v2_sidebar: '1', vehicle_usage_set: { name: 'v2-set' } }
    end
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#vehicle-usage-set-form-sidebar', 0
  end

  test 'v2 update from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    patch :update, params: { id: @vehicle_usage_set, v2_sidebar: '1', vehicle_usage_set: { name: 'v2-updated-set' } }
    assert_response :success
    assert_equal 'v2-updated-set', @vehicle_usage_set.reload.name
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#vehicle-usage-set-form-sidebar', 0
  end

  test 'should get new vehicle_usage_set' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count') do
      assert_difference('VehicleUsage.count', customers(:customer_one).vehicles.length) do
        post :create, params: { vehicle_usage_set: { name: @vehicle_usage_set.name } }
      end
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should create vehicle_usage_set with time exceeding one day' do
    post :create, params: { vehicle_usage_set: { name: 'toto', time_window_start: '20:00', time_window_end: '08:00', time_window_end_day: '1' } }
    assert_equal VehicleUsageSet.last.time_window_start, 20 * 3_600
    assert_equal VehicleUsageSet.last.time_window_end, 32 * 3_600
  end

  test 'should create vehicle_usage_set with default time_window_end' do
    post :create, params: { vehicle_usage_set: { name: 'toto', time_window_start: '16:00', time_window_end_day: '1' } }
    assert VehicleUsageSet.last.time_window_start, 16 * 3_600
    assert VehicleUsageSet.last.time_window_end, 18 * 3_600
  end

  test 'should not create vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', 0) do
      post :create, params: { vehicle_usage_set: { name: '' } }
    end

    assert_template :new
    vehicle_usage_set = assigns(:vehicle_usage_set)
    assert vehicle_usage_set.errors.any?
    assert_valid response
  end

  test 'should get edit vehicle_usage_set' do
    get :edit, params: { id: @vehicle_usage_set }
    assert_response :success
    assert_valid response
    assert_select '.input-group-addon', minimum: 1
    assert_select '#vehicle_usage_set_rest_type_input .form-check', 2
    assert_select 'input.form-check-input[name=?]', 'vehicle_usage_set[rest_mode]', 2
    assert_select '#vehicle_usage_set_rest_duration:not([disabled])'
    assert_select '#vehicle_usage_set_rest_lapse:not([disabled])'
    assert_select '#vehicle_usage_set_rest_lapse' do |nodes|
      assert nodes.first['value'].blank?
    end
  end

  test 'should update vehicle_usage_set' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: 'toto', time_window_start: @vehicle_usage_set.time_window_start } }
    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should update vehicle_usage_set with regulatory rest' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { rest_mode: 'regulatory', rest_start: '', rest_stop: '', rest_duration: '00:45', rest_lapse: '06:00', store_rest_id: '' } }
    assert_redirected_to vehicle_usage_sets_path
    @vehicle_usage_set.reload
    assert_equal 45.minutes.to_i, @vehicle_usage_set.rest_duration
    assert_equal 6.hours.to_i, @vehicle_usage_set.rest_lapse
    assert_nil @vehicle_usage_set.rest_start
    assert_nil @vehicle_usage_set.rest_stop
  end

  test 'should update vehicle_usage_set with time exceeding one day' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: 'toto', time_window_start: '20:00', time_window_end: '08:00', time_window_end_day: '1' } }
    @vehicle_usage_set.reload
    assert_equal @vehicle_usage_set.time_window_start, 20 * 3_600
    assert_equal @vehicle_usage_set.time_window_end, 32 * 3_600

    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: 'toto', time_window_start: '08:00', time_window_start_day: '1', time_window_end: '12:00', time_window_end_day: '1', rest_start: '10:00', rest_start_day: '1', rest_stop: '11:00', rest_stop_day: '1', rest_duration: '01:00' } }
    @vehicle_usage_set.reload
    assert_equal @vehicle_usage_set.time_window_start, 32 * 3_600
    assert_equal @vehicle_usage_set.time_window_end, 36 * 3_600
    assert_equal @vehicle_usage_set.rest_start, 34 * 3_600
    assert_equal @vehicle_usage_set.rest_stop, 35 * 3_600
  end

  test 'should not update vehicle_usage_set' do
    patch :update, params: { id: @vehicle_usage_set, vehicle_usage_set: { name: '' } }

    assert_template :edit
    vehicle_usage_set = assigns(:vehicle_usage_set)
    assert vehicle_usage_set.errors.any?
    assert_valid response
  end

  test 'should destroy vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', -1) do
      delete :destroy, params: { id: @vehicle_usage_set }
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should disable/enable multiple vehicles' do
    vehicle_usage_set = @vehicle_usage_set.customer.vehicle_usage_sets.first
    vu_hash = {vehicle_usage_set.id.to_s => {}}
    vehicle_usage_set.vehicle_usages.each{ |vu| vu_hash[vehicle_usage_set.id.to_s][vu.id] = 'on' }

    [{action: 'disable_multiple', result: [false, false]}, {action: 'enable_multiple', result: [true, true]}].each do |obj|
      delete :destroy_multiple, params: { vehicle_usages: vu_hash, id: @vehicle_usage_set, obj[:action] => vehicle_usage_set.id }
      assert_equal obj[:result], VehicleUsage.where(vehicle_usage_set_id: vehicle_usage_set).map(&:active)
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should destroy multiple vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', -1) do
      delete :destroy_multiple, params: { vehicle_usage_sets: { vehicle_usage_sets(:vehicle_usage_set_one).id => 1 } }
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should destroy multiple vehicle_usage_set, 0 item' do
    assert_difference('VehicleUsageSet.count', 0) do
      delete :destroy_multiple
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should duplicate vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count') do
      patch :duplicate, params: { vehicle_usage_set_id: @vehicle_usage_set }
    end

    assert_redirected_to edit_vehicle_usage_set_path(assigns(:vehicle_usage_set))
  end

  test 'should reorder vehicle usages' do
    first = vehicle_usages(:vehicle_usage_one_one)
    second = vehicle_usages(:vehicle_usage_one_three)

    patch :reorder_vehicle_usages, params: {
      id: @vehicle_usage_set.id,
      vehicle_usage_ids: [second.id, first.id]
    }

    assert_response :success
    assert_equal [0, 1], [second.reload.index, first.reload.index]
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
    assert_select 'form[action=?]', import_csv_vehicle_usage_sets_path, 1
    assert_select 'form .offset-md-1.col-md-10', minimum: 1
    assert_select 'form a.btn[href=?]', import_template_vehicle_usage_sets_path(format: :excel), 1
  end

  test 'import disables file field when vehicle_usages form is read-only' do
    return unless Role.column_names.include?('forms')

    u = users(:user_one)
    role = Role.create!(
      reseller: @reseller,
      name: "vus-import-ro-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(
        'vehicle_usages' => { 'visible' => true, 'usable' => false }
      )
    )
    u.update!(role_id: role.id)
    sign_in u

    get :import
    assert_response :success
    assert_select 'fieldset[disabled] input[type=file]'
  ensure
    u.update!(role_id: nil) if u.reload.role_id.present?
    role&.destroy
    sign_in users(:user_one)
  end

  test 'upload_csv returns forbidden when vehicle_usages form is read-only' do
    return unless Role.column_names.include?('forms')

    u = users(:user_one)
    role = Role.create!(
      reseller: @reseller,
      name: "vus-upload-ro-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(
        'vehicle_usages' => { 'visible' => true, 'usable' => false }
      )
    )
    u.update!(role_id: role.id)
    sign_in u

    file = fixture_file_upload('import_vehicle_usage_sets_one.csv', 'text/csv')
    post :upload_csv, params: { import_csv: { replace_vehicles: true, file: file } }
    assert_response :forbidden
  ensure
    u.update!(role_id: nil) if u.reload.role_id.present?
    role&.destroy
    sign_in users(:user_one)
  end

  test 'should show import template' do
    [:csv, :excel].each { |format|
      get :import_template, params: { format: format }
      assert_response :success
    }
  end

  test 'should export vehicle usage set to csv or excel' do
    [:csv, :excel].each { |format|
      get :show, params: { id: @vehicle_usage_set, format: format }
      assert_response :success
      assert_valid response
      assert_match 'text/csv', response.content_type
    }
  end

  test 'should export vehicle usage set to csv whith custom attributes' do
    get :show, params: { id: @vehicle_usage_set, format: :csv }
    assert_response :success
    assert_valid response
    assert_equal 'text/csv; charset=utf-8', response.content_type

    csv = CSV.new(response.body)
    headers = csv.first

    vehicle_one = vehicles(:vehicle_one)
    vehicle_three = vehicles(:vehicle_three)
    vehicles_by_ref = {
      vehicle_one.ref => vehicle_one,
      vehicle_three.ref => vehicle_three
    }
    csv.each do |line|
      vehicle = vehicles_by_ref[line[1]]
      assert vehicle, "Unexpected vehicle ref in CSV: #{line[1].inspect}"
      ['one', 'two', 'three'].each { |key|
        attr_index = headers.index { |header| header.include?("[custom_attribute_#{key}]") }
        assert attr_index
        assert_equal vehicle.custom_attributes_typed_hash["custom_attribute_#{key}"].to_s, line[attr_index]
      }
    end
  end

  test 'should upload' do
    file = fixture_file_upload('import_vehicle_usage_sets_one.csv', 'text/csv')

    assert_difference('VehicleUsageSet.count', 1) do
      post :upload_csv, params: { import_csv: { replace_vehicles: true, file: file } }
    end

    assert_redirected_to vehicle_usage_sets_path
  end

  test 'should use limitation' do
    customer = @vehicle_usage_set.customer
    customer.max_vehicle_usage_sets = customer.vehicle_usage_sets.size + 1
    customer.save!

    assert_difference('VehicleUsageSet.count', 1) do
      post :create, params: { vehicle_usage_set: {
        name: 'new dest',
      } }
      assert_response :redirect
    end

    assert_difference('VehicleUsageSet.count', 0) do
      assert_difference('VehicleUsage.count', 0) do
        post :create, params: { vehicle_usage_set: {
          name: 'new 2',
        } }
      end
    end
  end
end
