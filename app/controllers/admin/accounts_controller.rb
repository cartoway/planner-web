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

class Admin::AccountsController < ApplicationController
  include V2Layout
  helper Admin::UsersHelper

  before_action :authenticate_user!
  before_action :require_reseller_admin
  before_action :find_account, except: %i[index new create destroy_multiple]

  helper_method :account_deletable?

  def index
    load_accounts
    if turbo_frame_request? && turbo_frame_request_id == 'accounts_list'
      render partial: 'v2/admin/accounts/list_frame', layout: false
    else
      render_page 'v2/admin/accounts/index'
    end
  end

  def new
    @account = Account.new
    # Turbo-frame new skips the load_accounts block; still need selects for the sidebar form.
    load_form_collections
    lock_customer_from_params
    prepare_new_sidebar_mode
    render_admin_form_or_list('new_sidebar', 'v2/admin/accounts/index', admin_accounts_path) { load_accounts }
  end

  def edit
    render_admin_form_or_list('edit_sidebar', 'v2/admin/accounts/index', admin_accounts_path) { load_accounts }
  end

  def create
    load_form_collections
    lock_customer_from_params
    prepare_new_sidebar_mode
    customer = reseller_customers.find(params[:customer_id])
    role_id = reseller_role_id(params[:role_id].presence || current_user.reseller.default_role_id)

    if @mode == 'existing'
      create_from_existing_account(customer, role_id)
    else
      create_new_account(customer, role_id)
    end
  rescue ActiveRecord::RecordNotUnique
    lock_customer_from_params
    prepare_new_sidebar_mode
    @account ||= Account.new(create_account_profile_params)
    @account.errors.add(:base, t('admin.accounts.form.duplicate_membership'))
    render 'new_sidebar', layout: false, status: :unprocessable_entity
  end

  def update
    Account.transaction do
      @account.update!(account_params)
      update_memberships
      add_membership
    end
    render_panel
  rescue ActiveRecord::RecordInvalid => e
    @account.errors.add(:base, e.record.errors.full_messages.to_sentence) if e.record != @account
    render 'edit_sidebar', layout: false, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @account.errors.add(:base, t('admin.accounts.form.duplicate_membership'))
    render 'edit_sidebar', layout: false, status: :unprocessable_entity
  end

  def destroy
    return head :forbidden if refusal(@account)

    @account.destroy
    render_removed
  end

  def destroy_multiple
    accounts = Account.where(id: scoped_accounts.select(:id)).where(id: Array(params[:accounts]&.keys))
    return head :forbidden if accounts.any? { |account| refusal(account) }

    accounts.each(&:destroy)
    respond_to do |format|
      format.turbo_stream { redirect_to admin_accounts_path, status: :see_other }
      format.html { redirect_to admin_accounts_path, status: :see_other }
    end
  end

  def send_email
    user = open_memberships(@account).first
    return head :unprocessable_entity unless user

    user.send_connection_message
    return redirect_to_customer_users_tab if return_to_customer_id.present?

    render_panel
  end

  def anonymize
    return head :forbidden if refusal(@account, anonymize: true)

    Accounts::AnonymizeJob.perform_later(@account.id)
    render_panel
  end

  def revoke_device
    device = @account.account_devices.find(params[:device_id])
    device.revoke!
    render_panel
  end

  def reauthorize_device
    device = @account.account_devices.find(params[:device_id])
    device.reauthorize!
    render_panel
  end

  def detach_membership
    membership = reseller_memberships.find(params[:membership_id])
    membership.update!(status: 'detached')
    return redirect_to_customer_users_tab if return_to_customer_id.present?

    render_panel
  end

  def account_deletable?(account)
    refusal(account).nil?
  end

  private

  def require_reseller_admin
    raise CanCan::AccessDenied unless current_user&.admin?
  end

  def reseller_customers
    current_user.reseller.customers
  end

  def scoped_accounts
    Account.for_reseller_customers(current_user.reseller_id).search(params[:q])
  end

  def load_accounts
    total = scoped_accounts.count
    per_page = helpers.accounts_index_per_page
    page = [params[:page].to_i, 1].max
    max_page = [(total.to_f / per_page).ceil, 1].max
    page = max_page if page > max_page
    @accounts = Account.where(id: scoped_accounts.select(:id))
                       .includes(users: %i[customer role])
                       .order(Arel.sql('LOWER(COALESCE(NULLIF(accounts.name, \'\'), accounts.email))'))
                       .offset((page - 1) * per_page)
                       .limit(per_page)
                       .to_a
    @pagination = { page: page, per_page: per_page, total: total }
    @roles = current_user.reseller.roles.order(:name)
    @customers = reseller_customers.order(:name)
  end

  def find_account
    @account = Account.find(params[:id])
    in_customers = @account.users.where(customer_id: reseller_customers.select(:id)).exists?
    reseller_admin = @account.users.where(reseller_id: current_user.reseller_id, customer_id: nil).exists?
    raise ActiveRecord::RecordNotFound unless in_customers || reseller_admin

    load_form_collections
  end

  def load_form_collections
    @roles = current_user.reseller.roles.order(:name)
    @customers = reseller_customers.order(:name)
    @memberships = reseller_memberships.includes(:customer, :role).order(:id) if @account&.persisted?
  end

  def prepare_new_sidebar_mode
    @mode = params[:mode].to_s
    @mode = 'new' unless %w[new existing].include?(@mode)
    return unless @mode == 'existing'

    already_linked = if @locked_customer
                       @locked_customer.users.with_open_status.select(:account_id)
                     else
                       Account.none
                     end
    attachable = Account.where(id: scoped_accounts.select(:id))
                        .where.not(id: already_linked)
                        .order(Arel.sql('LOWER(COALESCE(NULLIF(accounts.name, \'\'), accounts.email))'))
    @attachable_account_options = attachable.map do |account|
      label = [account.name.presence, account.email.presence].compact.join(' — ')
      [label.presence || t('admin.accounts.form.no_email'), account.id]
    end
  end

  def create_from_existing_account(customer, role_id)
    existing = Account.where(id: scoped_accounts.select(:id)).find_by(id: params[:existing_account_id])
    unless existing
      @account = Account.new
      @account.errors.add(:base, t('admin.accounts.form.existing_account_blank'))
      render 'new_sidebar', layout: false, status: :unprocessable_entity
      return
    end

    user = build_membership(existing, existing.email, customer, role_id)
    if user.save
      deliver_invitation(user, true)
      @account = existing
      finish_create
    else
      @account = existing
      user.errors.full_messages.each { |message| @account.errors.add(:base, message) }
      render 'new_sidebar', layout: false, status: :unprocessable_entity
    end
  end

  def create_new_account(customer, role_id)
    email = params.dig(:account, :email).to_s.strip
    @account = Account.new(create_account_profile_params.merge(email: email))
    if email.blank?
      @account.errors.add(:email, :blank)
      render 'new_sidebar', layout: false, status: :unprocessable_entity
      return
    end
    if Account.lookup_email(email)
      @account.errors.add(:email, :taken)
      @account.errors.add(:base, t('admin.accounts.form.email_taken'))
      render 'new_sidebar', layout: false, status: :unprocessable_entity
      return
    end

    user = build_membership(nil, email, customer, role_id)
    assign_create_account_profile(user)
    if user.save
      deliver_invitation(user, false)
      @account = user.account
      finish_create
    else
      user.errors.full_messages.each { |message| @account.errors.add(:base, message) }
      @account.assign_attributes(create_account_profile_params)
      render 'new_sidebar', layout: false, status: :unprocessable_entity
    end
  end

  def finish_create
    return redirect_to_customer_users_tab if return_to_customer_id.present?

    respond_to do |format|
      format.turbo_stream { render_created }
      format.html { redirect_to admin_accounts_path, status: :see_other }
    end
  end

  def reseller_memberships
    @account.users.for_customer_ids(reseller_customers.select(:id))
  end

  def open_memberships(account)
    account.users.for_customer_ids(reseller_customers.select(:id)).with_open_status.order(:id)
  end

  def account_params
    params.require(:account).permit(:email, :name, :phone, :locale, :time_zone)
  end

  def create_account_profile_params
    params.fetch(:account, {}).permit(:name, :phone, :time_zone)
  end

  # New-account sidebar fields only (existing-account attach skips this).
  def assign_create_account_profile(user)
    profile = create_account_profile_params
    user.build_account(email: user.email) unless user.account
    user.account.assign_attributes(profile)
  end

  def reseller_role_id(role_id)
    return nil if role_id.blank?
    return role_id if current_user.reseller.roles.exists?(id: role_id)

    nil
  end

  def build_membership(existing, email, customer, role_id)
    if existing
      existing.users.build(
        customer: customer,
        role_id: role_id,
        status: 'active',
        relationship: 'employee',
        email: existing.email
      )
    else
      password = User.generate_temporary_password
      User.new(
        email: email,
        password: password,
        password_confirmation: password,
        customer: customer,
        role_id: role_id,
        status: 'active',
        relationship: 'employee'
      )
    end
  end

  def deliver_invitation(user, existing)
    return unless ActiveModel::Type::Boolean.new.cast(params[:send_email])

    existing ? user.send_connection_message : user.send_password_email
  end

  def update_memberships
    (params[:memberships] || {}).each do |id, attrs|
      membership = reseller_memberships.find_by(id: id)
      next unless membership

      membership.update!(
        role_id: membership_role_id(membership, attrs[:role_id]),
        status: attrs[:status],
        relationship: attrs[:relationship],
        time_zone: attrs[:time_zone].presence
      )
    end
  end

  # Blank clears the role; unknown/foreign role_id keeps the current one (no silent wipe).
  def membership_role_id(membership, role_id)
    return nil if role_id.blank?

    resolved = reseller_role_id(role_id)
    resolved.nil? ? membership.role_id : resolved
  end

  def add_membership
    customer_id = params.dig(:new_membership, :customer_id)
    return if customer_id.blank?

    customer = reseller_customers.find(customer_id)
    @account.users.create!(
      customer: customer,
      role_id: reseller_role_id(params.dig(:new_membership, :role_id)),
      status: 'active',
      relationship: 'employee',
      email: @account.email
    )
  end

  def refusal(account, anonymize: false)
    return :self if account.id == current_user.account_id
    return :reseller_admin if reseller_admin_account?(account)
    return :other_reseller if other_reseller_open_account?(account)
    return :anonymized if anonymize && account.anonymized?

    nil
  end

  # Prefer in-memory users when includes(users: ...) already ran (index rows).
  def reseller_admin_account?(account)
    rid = current_user.reseller_id
    if account.association(:users).loaded?
      account.users.any? { |user| user.reseller_id == rid && user.customer_id.nil? }
    else
      account.users.where(reseller_id: rid, customer_id: nil).exists?
    end
  end

  def other_reseller_open_account?(account)
    rid = current_user.reseller_id
    if account.association(:users).loaded?
      account.users.any? { |user| open_other_reseller_membership?(user, rid) }
    else
      open = account.users.where(status: User::OPEN_STATUSES)
      open.joins(:customer).where.not(customers: { reseller_id: rid }).exists? ||
        open.where(customer_id: nil).where.not(reseller_id: [nil, rid]).exists?
    end
  end

  def open_other_reseller_membership?(user, rid)
    return false unless User::OPEN_STATUSES.include?(user.status)

    if user.customer_id.nil?
      user.reseller_id.present? && user.reseller_id != rid
    else
      user.customer && user.customer.reseller_id != rid
    end
  end

  def row_locals(account)
    { account: account }
  end

  def return_to_customer_id
    params[:return_to_customer_id].presence
  end

  def lock_customer_from_params
    customer_id = params[:customer_id].presence || return_to_customer_id
    @locked_customer = reseller_customers.find_by(id: customer_id) if customer_id
  end

  # Back to the customer sidebar users tab (create / mail / detach from that context).
  def redirect_to_customer_users_tab
    redirect_to edit_customer_path(return_to_customer_id, sidebar_tab: 'users'), status: :see_other
  end

  def render_created
    render_streams(
      stream_append('accounts-list', partial: 'v2/admin/accounts/list_row', locals: row_locals(@account)),
      stream_index_count(count: @accounts_count_after = scoped_accounts.count, help: t('admin.accounts.index.count_help'), model_key: 'admin.accounts.count', filterable: false),
      close_sidebar: true
    )
  end

  def render_removed
    respond_to do |format|
      format.turbo_stream do
        render_streams(
          stream_remove(@account),
          stream_index_count(count: scoped_accounts.count, help: t('admin.accounts.index.count_help'), model_key: 'admin.accounts.count', filterable: false),
          close_sidebar: false
        )
      end
      format.html { redirect_to admin_accounts_path, status: :see_other }
    end
  end

  def render_panel
    load_form_collections
    html = render_to_string(template: 'admin/accounts/edit_sidebar', formats: [:html], layout: false)
    render turbo_stream: [
      turbo_stream.replace('form_sidebar', html: html),
      stream_replace(@account, partial: 'v2/admin/accounts/list_row', locals: row_locals(@account))
    ]
  end
end
