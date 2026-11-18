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

# Web workspace context, multi-tab guard, and admin login-as.
# Contract: Warden/true_user is the real signed-in identity. During admin login-as,
# session[:workspace_user_id] is the membership the app acts as; current_user returns
# that user. stop clears the key (no Warden switch). Same-account switch still swaps Warden.
module WorkspaceSession # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  WORKSPACE_HEADER = 'X-Cartoway-Workspace'
  WORKSPACE_CHANGED_HEADER = 'X-Cartoway-Workspace-Changed'
  WORKSPACE_USER_SESSION = :workspace_user_id
  # Legacy B key — cleared on write/clear so old sessions cannot escalate via stop.
  IMPERSONATOR_SESSION = :impersonator_user_id

  included do
    helper_method :workspace_context_customer, :workspace_chip_label, :workspace_web_list,
                  :workspace_mobile_only_list, :workspace_show_menu?, :workspace_show_filter?,
                  :workspace_active_user_id, :workspace_impersonating?, :true_user,
                  :workspace_reseller_scope?, :workspace_reseller_admin, :workspace_reseller_web_list

    before_action :guard_workspace_header, if: :user_signed_in?
  end

  def after_sign_in_path_for(resource)
    return super unless resource.is_a?(User)

    clear_workspace_user_session!
    account = resource.account
    web = Workspaces::ListFor.call(account, channel: :web)
    if web.size <= 1
      account.update_columns(last_user_id: resource.id) if web.size == 1
      return stored_location_for(resource) || root_path
    end

    preferred = web.find { |user| user.id == account.last_user_id }
    if preferred
      if preferred.id != resource.id
        return choose_workspace_path unless apply_web_membership!(preferred, from_user: resource)
      elsif !Workspaces::ListFor.web_workspace?(resource)
        # Prefered is current but no longer a web workspace — force choose.
        return choose_workspace_path
      end
      account.update_columns(last_user_id: preferred.id)
      return stored_location_for(resource) || root_path
    end

    choose_workspace_path
  end

  # Real Devise/Warden identity (admin during login-as).
  def true_user
    warden.user(:user)
  end

  # Effective user for the app: workspace target while login-as is allowed, else true_user.
  def current_user
    workspace_user || true_user
  end

  def workspace_context_customer
    return nil unless user_signed_in?

    current_user.customer
  end

  def workspace_chip_label
    customer = workspace_context_customer
    return customer.name if customer
    return t('workspaces.chip.admin', name: true_user.reseller.name) if true_user&.admin?

    current_user.email
  end

  def workspace_web_list
    return [] unless user_signed_in?
    return [] if workspace_reseller_scope?

    @workspace_web_list ||= Workspaces::ListFor.call(current_user.account, channel: :web)
  end

  def workspace_mobile_only_list
    return [] unless user_signed_in?
    return [] if workspace_reseller_scope?

    @workspace_mobile_only_list ||= Workspaces::ListFor.mobile_only(current_user.account)
  end

  # Admin (including during login-as) sees every web user of the reseller.
  def workspace_reseller_scope?
    user_signed_in? && true_user&.admin?
  end

  def workspace_reseller_admin
    return true_user if user_signed_in? && true_user&.admin?

    nil
  end

  def workspace_reseller_web_list
    admin = workspace_reseller_admin
    return [] unless admin&.admin?

    @workspace_reseller_web_list ||= Workspaces::ListFor.reseller_web(admin)
  end

  # Chip is rendered only when this is true (no disabled single-space chip).
  def workspace_show_menu?
    return false unless user_signed_in?
    return true if workspace_reseller_scope? && workspace_reseller_web_list.any?
    return true if workspace_impersonating?

    workspace_web_list.size >= 2
  end

  def workspace_show_filter?
    return false unless user_signed_in?

    entries = workspace_reseller_scope? ? workspace_reseller_web_list.size : workspace_web_list.size
    entries >= 5
  end

  def workspace_active_user_id
    current_user&.id
  end

  def workspace_impersonating?
    user_signed_in? && workspace_user.present?
  end

  private

  def workspace_user
    return @workspace_user if defined?(@workspace_user)

    @workspace_user = nil
    wid = session[WORKSPACE_USER_SESSION]
    return nil if wid.blank?

    target = User.unscope(:order).find_by(id: wid)
    unless workspace_user_allowed?(true_user, target)
      clear_workspace_user_session!
      return nil
    end

    @workspace_user = target
  end

  def workspace_user_allowed?(admin, target)
    Workspaces::EffectiveUser.allowed?(admin, target)
  end

  def set_workspace_user!(user)
    session.delete(IMPERSONATOR_SESSION)
    session[WORKSPACE_USER_SESSION] = user.id
    @current_user = nil
    remove_instance_variable(:@workspace_user) if defined?(@workspace_user)
  end

  def clear_workspace_user_session!
    session.delete(WORKSPACE_USER_SESSION)
    session.delete(IMPERSONATOR_SESSION)
    @current_user = nil
    remove_instance_variable(:@workspace_user) if defined?(@workspace_user)
  end

  # Shared membership activation used by switch and after_sign_in.
  # Returns success boolean; bang marks the side-effecting session switch.
  def apply_web_membership!(user, from_user:) # rubocop:disable Naming/PredicateMethod
    result = Workspaces::Activate.call(
      account: from_user.account,
      user_id: user.id,
      channel: :web,
      from_user_id: from_user.id
    )
    return false unless result.status == 200

    clear_workspace_driver_state!
    clear_workspace_user_session!
    switch_warden_user!(result.user)
    true
  end

  # Switch signed-in user without Devise sign_out (sign_out calls reset_session → CSRF break).
  def switch_warden_user!(user)
    warden.set_user(user, scope: :user, run_callbacks: false)
    @current_user = nil # Devise memoizes current_user before actions like claim/guard
    remove_instance_variable(:@workspace_user) if defined?(@workspace_user)
  end

  def record_workspace_switch!(from_user_id:, to_user_id:, result:, account: nil)
    WorkspaceSwitchEvent.create!(
      account: account || current_user.account,
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      channel: 'web',
      result: result,
      created_at: Time.current
    )
  end

  def clear_workspace_driver_state!
    session.delete(:current_driver_id)
  end

  def guard_workspace_header
    return if request.get? || request.head?
    return if devise_controller?

    header = request.headers[WORKSPACE_HEADER].presence || params[:cartoway_workspace].presence
    return if header.blank?
    return if header.to_s == current_user.id.to_s

    response.set_header(WORKSPACE_CHANGED_HEADER, '1')
    respond_to do |format|
      format.html { render plain: t('workspaces.tabs.changed'), status: :conflict }
      format.json { render json: { error: 'workspace_changed', message: t('workspaces.tabs.changed') }, status: :conflict }
      format.any { head :conflict }
    end
  end
end
