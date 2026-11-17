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

class WorkspacesController < ApplicationController
  include V2Layout

  layout 'v2/layouts/application'

  before_action :authenticate_user!, except: %i[claim claim_prompt]

  def choose
    @web_workspaces = Workspaces::ListFor.call(current_user.account, channel: :web)
    redirect_to root_path if @web_workspaces.size <= 1 && !true_user.admin?
  end

  def switch
    if params[:stop_impersonating].present?
      stop_impersonating
    else
      switch_membership
    end
  end

  # POST: authorize + issue token. Same-host (customers/accounts connect-as) claims inline —
  # Turbo fetch drops Location fragments, so redirecting to /claim#token= never reaches claim_prompt.
  # Cross-host still redirects with #token= for the claim_prompt auto-submit.
  def handoff
    target = User.unscope(:order).find_by(id: params[:user_id])
    decision = Workspaces::HandoffPolicy.authorize(
      actor: true_user,
      target: target,
      reseller_admin: workspace_reseller_admin
    )
    unless decision.allowed
      record_workspace_switch!(from_user_id: true_user.id, to_user_id: params[:user_id], result: 'refused')
      redirect_to root_path, alert: t('workspaces.switch.failure')
      return
    end

    token = Workspaces::HandoffToken.generate(user: target, impersonator: decision.impersonator)
    if handoff_same_host?(target)
      apply_handoff_token!(token)
    else
      # Absolute http(s)://reseller.host can break Turbo fetch (CORS / http vs https behind proxy).
      redirect_to handoff_claim_location(token: token, target: target), status: :see_other
    end
  end

  # GET: page reads token from URL fragment (not sent to server) and POSTs claim.
  # Prefetch/scanners must not burn the one-shot JTI; query string avoided for logs/Referer.
  def claim_prompt
    # Legacy ?token= still accepted for tests / old links; preferred transport is #token=.
    @token = params[:token].to_s
    render :claim_prompt
  end

  # POST: consume handoff token (same or other host). One-shot.
  # Login-as: keep Warden as admin, set workspace_user_id. Cold claim: Warden = target.
  def claim
    apply_handoff_token!(params[:token])
  end

  private

  def apply_handoff_token!(token)
    result = Workspaces::HandoffToken.parse(token)
    unless result
      redirect_to claim_failure_location, alert: t('workspaces.handoff.invalid')
      return
    end

    unless claim_host_allowed?(result.user)
      record_workspace_switch!(
        account: result.user.account,
        from_user_id: user_signed_in? ? true_user.id : nil,
        to_user_id: result.user.id,
        result: 'refused'
      )
      redirect_to claim_failure_location, alert: t('workspaces.handoff.invalid')
      return
    end

    actor = user_signed_in? ? true_user : nil
    decision = Workspaces::HandoffPolicy.claim(
      actor: actor,
      target: result.user,
      token_impersonator: result.impersonator,
      current_impersonator: workspace_impersonating? ? true_user : nil
    )
    unless decision.allowed
      record_workspace_switch!(
        account: result.user.account,
        from_user_id: actor&.id,
        to_user_id: result.user.id,
        result: 'refused'
      )
      redirect_to claim_failure_location, alert: t('workspaces.handoff.invalid')
      return
    end

    # Burn only after policy allows so a refused claim can still be retried.
    unless Workspaces::HandoffToken.consume!(result.jti)
      redirect_to claim_failure_location, alert: t('workspaces.handoff.invalid')
      return
    end
    login_as_admin = decision.impersonator

    clear_workspace_driver_state!

    if login_as_admin
      switch_warden_user!(login_as_admin) unless true_user&.id == login_as_admin.id
      set_workspace_user!(result.user)
    else
      clear_workspace_user_session!
      # Cold claim only: avoid session fixation without wiping an existing same-account session.
      reset_session if actor.nil?
      switch_warden_user!(result.user)
      result.user.account.update_columns(last_user_id: result.user.id)
    end

    record_workspace_switch!(
      account: login_as_admin ? login_as_admin.account : result.user.account,
      from_user_id: login_as_admin&.id || actor&.id,
      to_user_id: result.user.id,
      result: 'ok'
    )

    name = result.user.customer&.name || result.user.email
    notice = login_as_admin ? t('workspaces.impersonation.started', name: name) : t('workspaces.switch.success', name: name)
    redirect_to root_path, notice: notice
  end

  def handoff_same_host?(target)
    target_host = target.customer&.reseller&.host.presence || @reseller&.host
    same_reseller = target.customer&.reseller_id.present? && target.customer.reseller_id == @reseller&.id
    same_reseller || target_host.blank? || target_host == request.host
  end

  def switch_membership
    # During login-as, only handoff changes workspace user (switch would swap Warden).
    if workspace_impersonating?
      record_workspace_switch!(from_user_id: current_user.id, to_user_id: params[:user_id], result: 'refused')
      redirect_to root_path, alert: t('workspaces.switch.failure')
      return
    end

    target_id = params[:user_id]
    target = current_user.account.users.unscope(:order).find_by(id: target_id)
    unless target
      # Activate still journals refused when account-scoped miss — call it for audit.
      Workspaces::Activate.call(account: current_user.account, user_id: target_id, channel: :web, from_user_id: current_user.id)
      redirect_to root_path, alert: t('workspaces.switch.failure')
      return
    end

    if apply_web_membership!(target, from_user: current_user)
      current_user.account.update_columns(last_user_id: target.id)
      redirect_to root_path, notice: t('workspaces.switch.success', name: target.customer.name)
    else
      redirect_to root_path, alert: t('workspaces.switch.failure')
    end
  end

  def stop_impersonating
    admin = true_user
    unless admin&.admin? && workspace_impersonating?
      clear_workspace_user_session!
      redirect_to root_path, alert: t('workspaces.switch.failure')
      return
    end

    from_id = current_user.id
    clear_workspace_driver_state!
    clear_workspace_user_session!
    record_workspace_switch!(
      account: admin.account,
      from_user_id: from_id,
      to_user_id: admin.id,
      result: 'ok'
    )
    redirect_to root_path, notice: t('workspaces.impersonation.stopped', name: admin.reseller.name)
  end

  def handoff_claim_location(token:, target:)
    fragment = "token=#{ERB::Util.url_encode(token)}"
    target_host = target.customer&.reseller&.host.presence || @reseller&.host
    same_reseller = target.customer&.reseller_id.present? && target.customer.reseller_id == @reseller&.id
    base = if same_reseller || target_host.blank? || target_host == request.host
             claim_workspace_path
           else
             claim_workspace_url(host: target_host, protocol: request.scheme)
           end
    "#{base}##{fragment}"
  end

  # Multi-tenant: refuse when host reseller is unresolved or does not match target.
  def claim_host_allowed?(target)
    return false if @reseller.blank?
    return true unless target.customer

    target.customer.reseller_id == @reseller.id
  end

  # Never send a signed-in user to the login page (Devise would replace the flash with
  # "already signed in").
  def claim_failure_location
    user_signed_in? ? root_path : new_user_session_path
  end
end
