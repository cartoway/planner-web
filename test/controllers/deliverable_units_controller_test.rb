require 'test_helper'

class DeliverableUnitsControllerTest < ActionController::TestCase

  setup do
    @request.env['reseller'] = resellers(:reseller_one)
    @deliverable_unit = deliverable_units(:deliverable_unit_one_one)
    sign_in users(:user_one)
    customers(:customer_one).update(enable_orders: false)
  end

  test 'user can only view deliverable units from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @deliverable_unit
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @deliverable_unit

    get :edit, id: deliverable_units(:deliverable_unit_two_one)
    assert_response :not_found
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:deliverable_units)
    assert_valid response
  end

  test 'should get new' do
    get :new
    assert_response :success
    assert_valid response
  end

  test 'should create deliverable unit' do
    assert_difference('DeliverableUnit.count') do
      post :create, deliverable_unit: { label: @deliverable_unit.label }
    end

    assert_redirected_to deliverable_units_path
  end

  test 'should not create deliverable unit' do
    assert_no_difference('DeliverableUnit.count') do
      post :create, deliverable_unit: { optimization_overload_multiplier: -1 }
    end

    assert_template :new
    deliverable_unit = assigns(:deliverable_unit)
    assert deliverable_unit.errors.any?
    assert_valid response
  end

  test 'should get edit' do
    get :edit, id: @deliverable_unit
    assert_response :success
    assert_valid response
  end

  test 'should update deliverable unit' do
    patch :update, id: @deliverable_unit, deliverable_unit: { label: @deliverable_unit.label }
    assert_redirected_to deliverable_units_path
  end

  test 'should not update deliverable unit' do
    patch :update, id: @deliverable_unit, deliverable_unit: { optimization_overload_multiplier: -1 }
    assert_template :edit
    deliverable_unit = assigns(:deliverable_unit)
    assert deliverable_unit.errors.any?
    assert_valid response
  end

  test 'should destroy deliverable unit' do
    assert_difference('DeliverableUnit.count', -1) do
      delete :destroy, id: @deliverable_unit
    end

    assert_redirected_to deliverable_units_path
  end

  test 'should destroy multiple deliverable units' do
    assert_difference('DeliverableUnit.count', -2) do
      delete :destroy_multiple, deliverable_units: { deliverable_units(:deliverable_unit_one_one).id => 1, deliverable_units(:deliverable_unit_one_two).id => 1 }
    end

    assert_redirected_to deliverable_units_path
  end

  test 'should return an icon in any situation' do
    #Default icon value is nil
    assert_equal "fa-archive", @deliverable_unit.default_icon, response.body

    @deliverable_unit.update! icon: "fa-home"
    assert_equal "fa-home", @deliverable_unit.default_icon, response.body
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
