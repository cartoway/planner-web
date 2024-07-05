class V01::OrderArrays < Grape::API
  helpers do
    def authorize!
      ability = Ability.new(@current_user)
      error!(V01::Status.code_response(:code_401), 401) unless ability.can?(:manage, OrderArray)
    end
  end

  resource :order_arrays do
    desc 'Orders mass assignment.',
      detail: 'Only available if "enable orders" option is active for current customer.',
      nickname: 'massAssignmentOrder',
      success: V01::Status.success(:code_200, V01::Entities::OrderArray),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      optional :orders, type: Hash, coerce_with: JSON
    end
    patch ':id' do
      if params[:orders]
        order_array = current_customer.order_arrays.find(params[:id])
        orders = Hash[order_array.orders.load.map{ |order| [order.id, order] }]
        products = Hash[current_customer.products.collect{ |product| [product.id, product] }]
        params[:orders].each{ |id, order|
          id = Integer(id.to_s)
          order[:product_ids] ||= []
          if orders.key?(id)
            orders[id].products.clear
            orders[id].products += order[:product_ids].map{ |product_id| products[Integer(product_id)] }.compact
          end
        }
        order_array.save!
      end
      status 200
    end
  end
end
