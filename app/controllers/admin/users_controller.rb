# Copyright © Mapotempo, 2013-2016
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class Admin::UsersController < ApplicationController
  load_and_authorize_resource

  before_action :find_user, except: [:index, :new, :create, :destroy_multiple]
  before_action :find_customers, except: [:index, :destroy_multiple]

  def index
    @users = User.from_customers_for_reseller_id(current_user.reseller_id)
  end

  def new
    @customer = Customer.find params[:customer_id] if params[:customer_id]
    @user = @customer ? @customer.users.new : User.new
  end

  def create
    password = Time.now.to_i + rand(10000)
    @user = User.new user_params.merge(password: password, password_confirmation: password)
    @user.save
    if @user.persisted?
      redirect_to_default
    else
      render action: :new
    end
  end

  def update
    if @user.update user_params
      redirect_to_default
    else
      render action: :edit
    end
  end

  def destroy
    @user.destroy if !@user.admin?
    redirect_to_default
  end

  def destroy_multiple
    User.find(params[:users].keys).reject(&:admin?).each(&:destroy)
    redirect_to_default
  end

  def send_email
    if @user.confirmation_token.nil? || @user.confirmation_token.empty?
      @user.confirmed_at = nil
      @user.generate_confirmation_token
      @user.save!
    end

    @user.send_password_email
    redirect_to_default
  end

  private

  def redirect_to_default
    redirect_to !params[:url].blank? ? params[:url] : admin_users_path, notice: t("admin.users.#{action_name}.success")
  end

  def find_customers
    @customers = current_user.reseller.customers.order(:name)
  end

  def find_user
    User.from_customers_for_reseller_id(current_user.reseller_id).find params[:id]
  end

  def user_params
    params.require(:user).permit(:email, :customer_id, :password, :password_confirmation, :time_zone, :send_email)
  end
end
