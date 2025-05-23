# Copyright © Mapotempo, 2014-2015
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
require 'coerce'

class V01::Users < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      p = ActionController::Parameters.new(params)
      p = p[:user] if p.key?(:user)
      if @current_user.admin?
        p.permit(:ref, :email, :password, :customer_id, :layer_id, :url_click2call, :time_zone, :locale, :prefered_unit)
      else
        p.permit(:layer_id, :url_click2call, :time_zone, :locale, :prefered_unit)
      end
    end
  end

  resource :users do
    desc 'Fetch customer\'s users (or all users with an admin key).',
      nickname: 'getUsers',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::User),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :email, type: String, desc: 'Only available with an admin api_key.'
    end
    get do
      if @current_user.admin?
        users = User.for_reseller_id(@current_user.reseller_id) + User.from_customers_for_reseller_id(@current_user.reseller.id)
        users.select! { |u| u.email == params[:email] } if params[:email]
      else
        users = @current_customer.users.load
      end
      present users, with: V01::Entities::User
    end

    desc 'Fetch user.',
      nickname: 'getUser',
      success: V01::Status.success(:code_200, V01::Entities::User),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    get ':id' do
      id = ParseIdsRefs.read(params[:id])
      if @current_user.admin?
        user = (User.for_reseller_id(@current_user.reseller_id).where(id) + User.from_customers_for_reseller_id(@current_user.reseller_id).where(id)).first
        if user
          present user, with: V01::Entities::User
        else
          error! V01::Status.code_response(:code_404), 404
        end
      else
        present @current_customer.users.where(id).first!, with: V01::Entities::User
      end
    end

    desc 'Create user (admin).',
      detail: 'Only available with an admin api_key.',
      nickname: 'createUser',
      success: V01::Status.success(:code_201, V01::Entities::User),
      failure: V01::Status.failures
    params do
      use(:request_user, create: true)
    end
    post do
      if @current_user.admin?
        customer = @current_user.reseller.customers.where(id: params[:customer_id]).first!
        user = customer.users.build(user_params)
        user.password_confirmation = user.password
        user.send_email = 1
        user.save!

        present user, with: V01::Entities::User
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end

    desc 'Update user.',
      nickname: 'updateUser',
      success: V01::Status.success(:code_200, V01::Entities::User),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      use :request_user
    end
    put ':id' do
      id = ParseIdsRefs.read(params[:id])
      user = (User.for_reseller_id(@current_user.reseller_id).where(id) + User.from_customers_for_reseller_id(@current_user.reseller_id).where(id)).first
      user.update! user_params
      present user, with: V01::Entities::User
    end

    desc 'Delete user (admin).',
      detail: 'Only available with an admin api_key.',
      nickname: 'deleteUser',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    delete ':id' do
      if @current_user.admin?
        id = ParseIdsRefs.read(params[:id])
        user = (User.for_reseller_id(@current_user.reseller_id).where(id) + User.from_customers_for_reseller_id(@current_user.reseller_id).where(id)).first
        user.destroy!
        status 204
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end

    desc 'Delete multiple users (admin).',
      detail: 'Only available with an admin api_key.',
      nickname: 'deleteUsers',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    delete do
      if @current_user.admin?
        User.transaction do
          (User.for_reseller_id(@current_user.reseller_id) + User.from_customers_for_reseller_id(@current_user.reseller_id)).select{ |user|
            params[:ids].any?{ |s| ParseIdsRefs.match(s, user) }
          }.each(&:destroy)
        end
        status 204
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end
  end
end
