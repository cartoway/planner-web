# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class Admin::RolesController < ApplicationController
  before_action :set_reseller
  before_action :set_role, only: %i[edit update destroy]
  before_action :set_role_icon_groups, except: [:index]

  def index
    authorize! :manage, Role
    @roles = @reseller.roles.order(:name)
  end

  def new
    authorize! :create, Role
    # Empty JSON columns default every form resource to visible+usable in the DnD split;
    # seed from catalog so new roles match config/default_permissions (+new_role+) and role_attributes on create.
    @role = @reseller.roles.build(
      operations: Preferences::Catalog.new_role_admin_operations_seed,
      forms: Preferences::Catalog.new_role_admin_forms_seed
    )
  end

  def create
    # Build first so role_attributes can use @role.new_record?
    @role = @reseller.roles.build
    authorize! :create, @role
    @role.assign_attributes(role_attributes)
    if @role.save
      redirect_to admin_roles_path, notice: t('admin.roles.flash.created')
    else
      render :new
    end
  end

  def edit
    authorize! :update, @role
  end

  def update
    authorize! :update, @role
    if @role.update(role_attributes)
      redirect_to admin_roles_path, notice: t('admin.roles.flash.updated')
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, @role
    @role.destroy
    redirect_to admin_roles_path, notice: t('admin.roles.flash.destroyed')
  end

  def destroy_multiple
    authorize! :manage, Role
    Role.transaction do
      if params[:roles]
        ids = params[:roles].keys.map { |i| Integer(i) }
        @reseller.roles.where(id: ids).find_each do |role|
          authorize! :destroy, role
          role.destroy
        end
      end
    end
    redirect_to admin_roles_path, notice: t('admin.roles.flash.destroyed_multiple')
  end

  def duplicate
    source = @reseller.roles.find(params[:id])
    authorize! :create, Role

    copy = @reseller.roles.build(
      name: unique_duplicate_name(source.name),
      icon: source.icon,
      color: source.color,
      operations: json_column_dup(source.operations),
      forms: json_column_dup(source.forms)
    )

    if copy.save
      redirect_to admin_roles_path, notice: t('admin.roles.flash.duplicated')
    else
      redirect_to admin_roles_path, alert: copy.errors.full_messages.to_sentence
    end
  end

  private

  def set_reseller
    @reseller = current_user.reseller
    raise ActiveRecord::RecordNotFound if @reseller.blank?
  end

  def set_role
    @role = @reseller.roles.find(params[:id])
  end

  def role_attributes
    p = params.require(:role).permit(
      :name,
      :ref,
      :icon,
      :color,
      :forms_ui,
      operations: {
        planning: [], planning_disabled: [], planning_hidden: [],
        route: [], route_disabled: [], route_hidden: [],
        stop: [], stop_disabled: [], stop_hidden: []
      },
      forms_active: [],
      forms_disabled: []
    )

    operations_seed = operations_seed_for_role_form
    operations_val = if p[:operations].present?
                       Preferences::Catalog.merge_operations_with_params(operations_seed, p[:operations])
                     else
                       Preferences::Catalog.normalize_operations(operations_seed)
                     end

    forms_seed = forms_seed_for_role_form
    raw_role = params.require(:role).to_unsafe_h.stringify_keys
    forms_val = if raw_role['forms_ui'].present?
                  Preferences::Catalog.merge_forms_with_params(forms_seed, raw_role)
                else
                  Preferences::Catalog.normalize_forms(forms_seed)
                end

    {
      name: p[:name],
      ref: p[:ref],
      # Same allowlist as TagsController#icons_table (FontAwesome::ICONS_TABLE); unknown tokens fail Role validation.
      icon: role_icon_param_for_attributes(p[:icon]),
      color: p[:color],
      operations: operations_val,
      forms: forms_val
    }
  end

  def role_icon_param_for_attributes(raw)
    FontAwesome.normalized_fa_icon_token(raw)
  end

  def set_role_icon_groups
    @grouped_role_icons = [FontAwesome::ICONS_TABLE_ROLE, (FontAwesome::ICONS_TABLE - FontAwesome::ICONS_TABLE_ROLE)]
  end

  def operations_seed_for_role_form
    return Preferences::Catalog.new_role_admin_operations_seed if @role.blank? || @role.new_record?

    @role.operations.present? ? @role.operations.deep_dup : Preferences::Catalog.new_role_admin_operations_seed
  end

  def forms_seed_for_role_form
    return Preferences::Catalog.new_role_admin_forms_seed if @role.blank? || @role.new_record?

    @role.forms.present? ? @role.forms.deep_dup : Preferences::Catalog.new_role_admin_forms_seed
  end

  def json_column_dup(value)
    return {} if value.nil?

    value.deep_dup
  end

  def unique_duplicate_name(base_name)
    suffix = I18n.t('admin.roles.duplicate_suffix')
    candidate = "#{base_name}#{suffix}"
    n = 2
    while @reseller.roles.exists?(name: candidate)
      candidate = "#{base_name}#{suffix} (#{n})"
      n += 1
    end
    candidate
  end
end
