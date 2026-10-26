require 'test_helper'

class DeliverableUnitsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @deliverable_unit = deliverable_units(:deliverable_unit_one_one)
    sign_in users(:user_one)
    customers(:customer_one).update(enable_orders: false)
  end

  test 'user can only view deliverable units from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @deliverable_unit
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @deliverable_unit

    get :edit, params: { id: deliverable_units(:deliverable_unit_two_one) }
    assert_response :not_found
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:deliverable_units)
    assert_valid response
  end

  test 'index uses v2 when user preference is set' do
    enable_layout_v2!
    get :index
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select %(a[href="#{new_deliverable_unit_path}"][data-turbo-frame="form_sidebar"]), 1
    assert_select '.deliverable-units-index', 1
    assert_select '#deliverable-units.v2-index-cards', 1
    assert_select '.v2-index-card', minimum: 1
    assert_select '.v2-index-card-actions .btn-primary', minimum: 1
    assert_select '.v2-index-card button[data-controller~="confirm-click"][data-confirm-click-url-value]', minimum: 1
    assert_select '.deliverable-units-toolbar button[data-controller~="confirm-click"][data-confirm-click-form-value][data-v2--table-selection-target=bulk]', 1
    assert_select '[data-controller*="v2--index-selection"]', 1
    assert_select '.deliverable-units-toolbar button[data-action*="v2--index-selection#toggle"] .fa-check-square', 1
  end

  test 'v2 index cards show field labels for present attributes' do
    enable_layout_v2!
    unit = deliverable_units(:deliverable_unit_one_one)
    get :index
    assert_response :success
    card = "##{ActionView::RecordIdentifier.dom_id(unit)}"
    # Fixed meta slots keep columns aligned across cards (same pattern as VUS nested list).
    assert_select "#{card} .du-meta-ref", 1
    assert_select "#{card} .du-meta-capacity", 1
    assert_select "#{card} .du-meta-pickup", 1
    assert_select "#{card} .du-meta-delivery", 1
    assert_select "#{card} .du-meta-overload", 1
    assert_select "#{card} .v2-index-card-meta-label",
                  text: /#{Regexp.escape(DeliverableUnit.human_attribute_name(:ref))}/,
                  minimum: 1
    assert_select "#{card} .v2-index-card-meta-value",
                  text: /#{Regexp.escape(unit.ref)}/,
                  minimum: 1
  end

  test 'v2 index cards show overload coefficient value only when allowed' do
    enable_layout_v2!
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.update!(optimization_overload_multiplier: 1.5)
    get :index
    assert_response :success
    card = "##{ActionView::RecordIdentifier.dom_id(unit)}"
    assert_select "#{card} .du-meta-overload .v2-index-card-meta-label",
                  text: /#{Regexp.escape(DeliverableUnit.human_attribute_name(:optimization_overload_multiplier))}/,
                  minimum: 1
    assert_select "#{card} .du-meta-overload .v2-index-card-meta-value",
                  text: /#{Regexp.escape(unit.reload.localized_optimization_overload_multiplier)}/,
                  minimum: 1
    assert_select "#{card} .du-meta-overload",
                  text: /#{Regexp.escape(I18n.t('deliverable_units.form.optimization_overload_multiplier_yes'))}/,
                  count: 0
  end

  test 'v2 index cards hide overload when not allowed' do
    enable_layout_v2!
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.update!(optimization_overload_multiplier: 0)
    get :index
    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(unit)} .du-meta-overload .v2-index-card-meta-label", 0
  end

  test 'edit responds with form_sidebar fragment when requested via Turbo Frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @deliverable_unit }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#deliverable-unit-form-sidebar.form-sidebar-form.form-sidebar-form--full-bleed', 1
    assert_select 'input.form-check-input[name=deliverable_unit_optimization_overload_multiplier]', 2
    assert_select 'select#deliverable_unit_icon[data-controller~="v2--tom-select"]', 1
    assert_select 'select#deliverable_unit_icon option[data-icon]', minimum: 1
  end

  test 'v2 edit html renders the list with the form inlined so the url is shareable' do
    enable_layout_v2!
    get :edit, params: { id: @deliverable_unit }
    assert_response :success
    assert_select '.deliverable-units-index', 1
    assert_select 'turbo-frame#form_sidebar form#deliverable-unit-form-sidebar.form-sidebar-form.form-sidebar-form--full-bleed', 1
  end

  test 'v2 new html renders the list with the form inlined without a nil edit path' do
    enable_layout_v2!
    get :new
    assert_response :success
    assert_select '.deliverable-units-index', 1
    assert_select 'turbo-frame#form_sidebar form#deliverable-unit-form-sidebar', 1
    assert assigns(:deliverable_units).all?(&:persisted?)
    assert_select '#deliverable-units-list .v2-index-card', assigns(:deliverable_units).size
  end

  test 'v2 create from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    assert_difference('DeliverableUnit.count') do
      post :create, params: { v2_sidebar: '1', deliverable_unit: { label: 'v2-sidebar-label', ref: 'v2-ref' } }
    end
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#deliverable-unit-form-sidebar', 0
  end

  test 'v2 update from sidebar closes the form frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    patch :update, params: { id: @deliverable_unit, v2_sidebar: '1', deliverable_unit: { label: 'v2-updated-label' } }
    assert_response :success
    assert_equal 'v2-updated-label', @deliverable_unit.reload.label
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'form#deliverable-unit-form-sidebar', 0
  end

  test 'v2 create from sidebar appends the list row via turbo stream' do
    enable_layout_v2!
    assert_difference('DeliverableUnit.count') do
      post :create, params: { v2_sidebar: '1', deliverable_unit: { label: 'v2-stream-label', ref: 'v2-stream-ref' } }, as: :turbo_stream
    end
    created = assigns(:deliverable_unit)
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.media_type
    assert_select "turbo-stream[action='update'][target='form_sidebar']", 1
    assert_select "turbo-stream[action='append'][target='deliverable-units-list']", 1
    assert_select "turbo-stream[action='replace'][target='count']", 1
    assert_includes response.body, ActionView::RecordIdentifier.dom_id(created)
    assert_includes response.body, 'v2-stream-label'
  end

  test 'v2 destroy removes the row and refreshes the count via turbo stream' do
    enable_layout_v2!
    assert_difference('DeliverableUnit.count', -1) do
      delete :destroy, params: { id: @deliverable_unit }, as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[action='remove'][target='#{ActionView::RecordIdentifier.dom_id(@deliverable_unit)}']", 1
    assert_select "turbo-stream[action='replace'][target='count']", 1
  end

  test 'v2 update from sidebar replaces the list row via turbo stream' do
    enable_layout_v2!
    patch :update, params: { id: @deliverable_unit, v2_sidebar: '1', deliverable_unit: { label: 'v2-stream-updated' } }, as: :turbo_stream
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.media_type
    assert_equal 'v2-stream-updated', @deliverable_unit.reload.label
    assert_select "turbo-stream[action='update'][target='form_sidebar']", 1
    assert_select "turbo-stream[action='replace'][target='#{ActionView::RecordIdentifier.dom_id(@deliverable_unit)}']", 1
    assert_includes response.body, 'v2-stream-updated'
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create deliverable unit' do
    assert_difference('DeliverableUnit.count') do
      post :create, params: { deliverable_unit: { label: 'new label' } }
    end

    assert_redirected_to deliverable_units_path
  end

  test 'should not create deliverable unit' do
    assert_no_difference('DeliverableUnit.count') do
      post :create, params: { deliverable_unit: { optimization_overload_multiplier: -1 } }
    end

    assert_template :new
    deliverable_unit = assigns(:deliverable_unit)
    assert deliverable_unit.errors.any?
    assert_valid response
  end

  test 'should not create deliverable unit with already existing label' do
    assert_no_difference('DeliverableUnit.count') do
      post :create, params: { deliverable_unit: { label: @deliverable_unit.label } }
    end

    assert_template :new
    deliverable_unit = assigns(:deliverable_unit)
    assert deliverable_unit.errors.any?
    assert_valid response
  end

  test 'should get edit' do
    get :edit, params: { id: @deliverable_unit }
    assert_response :success
    assert_valid response
  end

  test 'should update deliverable unit' do
    patch :update, params: { id: @deliverable_unit, deliverable_unit: { label: @deliverable_unit.label } }
    assert_redirected_to deliverable_units_path
  end

  test 'should not update deliverable unit' do
    patch :update, params: { id: @deliverable_unit, deliverable_unit: { optimization_overload_multiplier: -1 } }
    assert_template :edit
    deliverable_unit = assigns(:deliverable_unit)
    assert deliverable_unit.errors.any?
    assert_valid response
  end

  test 'should destroy deliverable unit' do
    assert_difference('DeliverableUnit.count', -1) do
      delete :destroy, params: { id: @deliverable_unit }
    end

    assert_redirected_to deliverable_units_path
  end

  test 'should destroy multiple deliverable units' do
    assert_difference('DeliverableUnit.count', -2) do
      delete :destroy_multiple, params: { deliverable_units: { deliverable_units(:deliverable_unit_one_one).id => 1, deliverable_units(:deliverable_unit_one_two).id => 1 } }
    end

    assert_redirected_to deliverable_units_path
  end

  test 'create is forbidden when deliverable_units form is read-only' do
    u = users(:user_one)
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['deliverable_units'] = Preferences::Catalog::Spaces.default_space_entry(
      'deliverable_units', visible: true, usable: false, actions_all_usable: false
    )
    spaces = Preferences::Catalog.normalize_spaces(spaces)
    role = Role.create!(
      reseller: @reseller,
      name: "ro-deliverable-units-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: spaces
    )
    u.update!(role_id: role.id)
    sign_in u

    assert_no_difference('DeliverableUnit.count') do
      post :create, params: { deliverable_unit: { label: 'blocked', ref: 'blocked-ref' } }
    end
    assert_response :forbidden
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end

  test 'destroy_multiple is forbidden when deliverable_units form is read-only' do
    u = users(:user_one)
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['deliverable_units'] = Preferences::Catalog::Spaces.default_space_entry(
      'deliverable_units', visible: true, usable: false, actions_all_usable: false
    )
    spaces = Preferences::Catalog.normalize_spaces(spaces)
    role = Role.create!(
      reseller: @reseller,
      name: "ro-deliverable-units-destroy-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: spaces
    )
    u.update!(role_id: role.id)
    sign_in u

    assert_no_difference('DeliverableUnit.count') do
      delete :destroy_multiple, params: { deliverable_units: { deliverable_units(:deliverable_unit_one_one).id => 1 } }
    end
    assert_response :forbidden
  ensure
    u.update!(role_id: nil)
    role&.destroy
    sign_in users(:user_one)
  end

  test 'should return an icon in any situation' do
    #Default icon value is nil
    assert_equal "fa-dumpster", @deliverable_unit.default_icon, response.body

    @deliverable_unit.update! icon: "fa-store"
    assert_equal "fa-store", @deliverable_unit.default_icon, response.body
  end

  test 'should remove unit when using enumarable' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_capacity: '-1,2')
    customers(:customer_one).deliverable_units.delete(unit)

    deleted_unit = customers(:customer_one).deliverable_units.where(id: unit.id).first

    assert_nil deleted_unit
  end

  test 'shoud makes routes outdated on unit deletion' do
    customer = customers(:customer_one)
    unit = customer.deliverable_units.first
    assert_difference('DeliverableUnit.count', -1) do
      customer.deliverable_units.delete(unit)
    end
    customer.save

    # Will be valid only if we keep the following logic : all routes == outdated on unit deletion
    customer.plannings.each { |planning|
      planning.routes.each { |route|
        assert route.outdated
      }
    }
  end
end
