# Copyright © Mapotempo, 2017
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

class V01::Devices::Sopac < Grape::API
  namespace :devices do
    namespace :sopac do
      helpers do
        def service
          SopacService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'List Devices.',
        detail: 'List Sopac devices.',
        nickname: 'deviceSopacList',
        is_array: true,
        success: V01::Status.success(:code_200, V01::Entities::DeviceItem),
        failure: V01::Status.failures(is_array: true)
      get '/devices' do
        present service.list_devices, with: V01::Entities::DeviceItem
      end
    end
  end
end
