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

  test 'new seeds spaces as visible but not usable (disabled tier)' do
    return unless Role.column_names.include?('spaces')

    get :new
    assert_response :success
    role = assigns(:role)
    active, disabled, hidden = role.spaces_resources_three_way_split
    assert_empty active
    assert_equal Preferences::Catalog::SPACE_KEYS.sort, disabled.sort
    assert_empty hidden
  end

  test 'index lists roles and assigns user counts per role' do
    get :index
    assert_response :success
    assert_kind_of ActiveRecord::Relation, assigns(:roles)
    assert assigns(:user_counts_by_role_id).is_a?(Hash)
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
    created = Role.order(:id).last
    assert_redirected_to edit_admin_role_path(created)
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
    if Role.column_names.include?('planning_toolbar')
      assert_equal @role.reload.planning_toolbar, copy.planning_toolbar
      assert_equal @role.spaces, copy.spaces if Role.column_names.include?('spaces')
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

  test 'update persists toolbar and space permissions' do
    return unless Role.column_names.include?('planning_toolbar')
    return unless Role.column_names.include?('spaces')

    patch :update, params: {
      id: @role.id,
      role: {
        name: @role.name,
        spaces_ui: '1',
        spaces_active: %w[plannings operations],
        spaces_disabled: %w[destination vehicle_usages],
        spaces_actions: {
          plannings: { active: %w[edit], disabled: [], hidden: [] },
          operations: {
            active: %w[sync transmit export],
            disabled: [],
            hidden: %w[destroy]
          }
        },
        planning_toolbar: {
          planning: %w[zoning optimize external_callback],
          route: %w[vehicle_usage export]
        }
      }
    }

    assert_redirected_to edit_admin_role_path(@role)
    @role.reload

    sp = Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_PLANNING
    expected_planning_segments = %w[zoning optimize external_callback] + (sp - %w[zoning optimize external_callback])
    assert_equal expected_planning_segments, @role.planning_toolbar['planning']['segments']

    sr = Preferences::Catalog::PLANNING_TOOLBAR_GROUPS_ROUTE
    expected_route_segments = %w[vehicle_usage export] + (sr - %w[vehicle_usage export])
    assert_equal expected_route_segments, @role.planning_toolbar['route']['segments']

    assert_equal Preferences::Catalog::SPACE_KEYS.sort, @role.spaces.keys.map(&:to_s).sort
    assert @role.spaces['plannings']['visible']
    assert @role.spaces['plannings']['usable']
    assert Preferences::Catalog::Spaces.space_action_usable_in?(@role.spaces['plannings'], 'edit')
    refute @role.spaces['customer']['visible']
    assert @role.spaces['destination']['visible']
    assert_not @role.spaces['destination']['usable']
    assert @role.spaces['operations']['usable']
    assert Preferences::Catalog::Spaces.space_action_usable_in?(@role.spaces['operations'], 'sync')
    assert_not Preferences::Catalog::Spaces.space_action_usable_in?(@role.spaces['operations'], 'destroy')
  end

  test 'edit form lists spaces section before toolbars and has no forms_active' do
    return unless Role.column_names.include?('planning_toolbar')
    return unless Role.column_names.include?('spaces')

    spaces = Preferences::Catalog.normalize_spaces(@role.spaces)
    spaces['plannings'] = Preferences::Catalog::Spaces.default_space_entry(
      'plannings', visible: true, usable: true, actions_all_usable: true
    )
    @role.update_column(:spaces, Preferences::Catalog.normalize_spaces(spaces))

    get :edit, params: { id: @role.id }
    assert_response :success
    assert_includes response.body, 'spaces_active'
    assert_not_includes response.body, 'forms_active'
    space_actions_accordion = ActionView::RecordIdentifier.dom_id(@role, 'space_actions_accordion')
    planning_toolbar_accordion = ActionView::RecordIdentifier.dom_id(@role, 'planning_toolbar_accordion')
    # assert_select: HAML emits id='…', not id="…"
    assert_select "##{space_actions_accordion}"
    assert_select "##{planning_toolbar_accordion}"
    assert_select "##{ActionView::RecordIdentifier.dom_id(@role, 'space_actions_plannings')}_collapse"
    assert_select "##{ActionView::RecordIdentifier.dom_id(@role, 'operations_planning')}_collapse"
    # Role.create! seeds toolbar segments in the disabled tier, so active inputs
    # ([planning_toolbar][planning][]) may be absent — use the accordion id as marker.
    spaces_pos = response.body.index('spaces_active')
    planning_pos = response.body.index(planning_toolbar_accordion)
    assert spaces_pos
    assert planning_pos
    assert_operator spaces_pos, :<, planning_pos
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

    assert_redirected_to edit_admin_role_path(@role)
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

  test 'destroy succeeds for reseller default role' do
    @reseller.update_column(:default_role_id, @role.id)

    assert_difference('Role.count', -1) do
      delete :destroy, params: { id: @role.id }
    end

    assert_redirected_to admin_roles_path
    assert_nil @reseller.reload.default_role_id
  end

  test 'destroy succeeds when users are assigned to role' do
    user = users(:user_one)
    user.update_column(:role_id, @role.id)

    assert_difference('Role.count', -1) do
      delete :destroy, params: { id: @role.id }
    end

    assert_redirected_to admin_roles_path
    assert_nil user.reload.role_id
  end
end
