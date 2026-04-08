# frozen_string_literal: true

require 'test_helper'

class Admin::RolesControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @controller = Admin::RolesController.new
    sign_in users(:user_admin)
    @role = Role.create!(
      reseller: @reseller,
      name: "Template A #{SecureRandom.hex(4)}"
    )
    @role.update!(icon: 'fa-star', color: '#cc0000') if Role.column_names.include?('icon')
  end

  test 'create persists name and optional icon and color' do
    assert_difference('Role.count', 1) do
      post :create, params: {
        role: {
          name: 'New role from test',
          ref: 'sales'
        }.tap { |r| r.merge!(icon: 'fa-truck', color: '#336699') if Role.column_names.include?('icon') }
      }
    end
    assert_redirected_to admin_roles_path
    created = Role.order(:id).last
    assert_equal 'New role from test', created.name
    assert_equal 'sales', created.ref
    if Role.column_names.include?('icon')
      assert_equal 'fa-truck', created.icon
      assert_equal '#336699', created.color
    end
  end

  test 'duplicate creates a copy and redirects to index' do
    assert_difference('Role.count', 1) do
      post :duplicate, params: { id: @role.id }
    end

    copy = Role.order(:id).last
    assert_not_equal @role.id, copy.id
    assert_includes copy.name, @role.name
    assert_redirected_to admin_roles_path
    if Role.column_names.include?('icon')
      assert_equal @role.icon, copy.icon
      assert_equal @role.color, copy.color
    end
    if Role.column_names.include?('operations')
      assert_equal @role.reload.operations, copy.operations
      assert_equal @role.forms, copy.forms
    end
  end

  test 'duplicate picks a unique name when copy already exists' do
    Role.create!(
      reseller: @reseller,
      name: "#{@role.name}#{I18n.t('admin.roles.duplicate_suffix')}"
    )

    assert_difference('Role.count', 1) do
      post :duplicate, params: { id: @role.id }
    end

    copy = Role.order(:id).last
    assert_match(/\(\d+\)\z/, copy.name)
  end

  test 'update persists toolbar and form permissions' do
    return unless Role.column_names.include?('operations')

    patch :update, params: {
      id: @role.id,
      role: {
        name: @role.name,
        forms_ui: '1',
        forms_active: %w[plannings],
        forms_disabled: %w[visits vehicle_usages],
        operations: {
          planning: %w[zoning optimize external_callback],
          route: %w[vehicle_usage export]
        }
      }
    }

    assert_redirected_to admin_roles_path
    @role.reload

    sp = Preferences::Catalog::OPERATION_GROUPS_PLANNING
    expected_planning_segments = %w[zoning optimize external_callback] + (sp - %w[zoning optimize external_callback])
    assert_equal expected_planning_segments, @role.operations['planning']['segments']

    sr = Preferences::Catalog::OPERATION_GROUPS_ROUTE
    expected_route_segments = %w[vehicle_usage export] + (sr - %w[vehicle_usage export])
    assert_equal expected_route_segments, @role.operations['route']['segments']

    assert_equal %w[visits plannings destinations vehicle_usages], @role.forms.keys.map(&:to_s)
    assert @role.forms['plannings']['visible']
    assert @role.forms['plannings']['usable']
    assert @role.forms['visits']['visible']
    assert_not @role.forms['visits']['usable']
  end

  test 'update persists metadata fields' do
    patch :update, params: {
      id: @role.id,
      role: {
        name: 'Renamed',
        ref: 'ops',
        icon: 'fa-bicycle',
        color: '#112233'
      }.compact
    }

    assert_redirected_to admin_roles_path
    @role.reload
    assert_equal 'Renamed', @role.name
    assert_equal 'ops', @role.ref
    if Role.column_names.include?('icon')
      assert_equal 'fa-bicycle', @role.icon
      assert_equal '#112233', @role.color
    end
  end

  test 'destroy_multiple deletes selected roles' do
    other = Role.create!(
      reseller: @reseller,
      name: 'Role B'
    )

    assert_difference('Role.count', -2) do
      delete :destroy_multiple, params: {
        roles: { @role.id.to_s => '1', other.id.to_s => '1' }
      }
    end

    assert_redirected_to admin_roles_path
  end
end
