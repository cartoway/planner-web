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
    assert_select 'table#deliverable-units', 1
    assert_select 'table#deliverable-units td.text-end > .btn-group', minimum: 1
    assert_select 'table#deliverable-units td.btn-group', 0
    assert_select '.deliverable-units-bulk [data-v2--table-selection-target=bulk]', 1
  end

  test 'edit responds with form_sidebar fragment when requested via Turbo Frame' do
    enable_layout_v2!
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @deliverable_unit }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'turbo-frame#form_sidebar form#deliverable-unit-form-sidebar', 1
    assert_select 'input.form-check-input[name=deliverable_unit_optimization_overload_multiplier]', 2
    assert_select 'select#deliverable_unit_icon[data-controller~="v2--tom-select"]', 1
    assert_select 'select#deliverable_unit_icon option[data-icon]', minimum: 1
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
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['deliverable_units'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "ro-deliverable-units-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
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
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['deliverable_units'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @reseller,
      name: "ro-deliverable-units-destroy-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
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
