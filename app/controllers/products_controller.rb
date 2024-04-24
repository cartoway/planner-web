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
class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: [:edit, :update, :destroy]

  load_and_authorize_resource

  def index
    @products = current_user.customer.products
  end

  def new
    @product = current_user.customer.products.build
  end

  def edit
  end

  def create
    @product = current_user.customer.products.build(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to products_path, notice: t('activerecord.successful.messages.created', model: @product.class.model_name.human) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to products_path, notice: t('activerecord.successful.messages.updated', model: @product.class.model_name.human) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @product.destroy
    respond_to do |format|
      format.html { redirect_to products_url }
    end
  end

  def destroy_multiple
    Product.transaction do
      if params['products']
        ids = params['products'].keys.collect{ |i| Integer(i) }
        current_user.customer.products.select{ |product| ids.include?(product.id) }.each(&:destroy)
      end
      respond_to do |format|
        format.html { redirect_to products_url }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_product
    @product = current_user.customer.products.find params[:id]
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def product_params
    params.require(:product).permit(:code, :name)
  end
end
