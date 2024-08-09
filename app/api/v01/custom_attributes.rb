require 'coerce'

class V01::CustomAttributes < Grape::API
  helpers SharedParams
  helpers do
    def session
      env[Rack::RACK_SESSION]
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def custom_attribute_params
      p = ActionController::Parameters.new(params)
      p = p[:custom_attributes] if p.key?(:custom_attributes)

      p.permit(:name, :object_type, :object_class, :default_value, :description)
    end
  end

  resource :custom_attributes do
    desc 'Fetch customer\'s custom_attributes.',
      nickname: 'getCustomAttributes',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::CustomAttribute),
      failure: V01::Status.failures(is_array: true, override: {code_404: 'CustomAttributes not found.'})
    params do
      optional :ids, type: Array[Integer], desc: 'Select returned custom_attributes by id.', coerce_with: CoerceArrayInteger
    end
    get do
      custom_attributes = current_customer.custom_attributes
      if custom_attributes && params.key?(:ids)
        custom_attributes = current_customer.custom_attributes.where(id: params[:ids])
      end
      if custom_attributes
        present custom_attributes, with: V01::Entities::CustomAttribute
      else
        error! V01::Status.code_response(:code_404, before: 'CustomAttribute'), 404
      end
    end

    desc 'Fetch custom_attribute.',
      nickname: 'getCustomAttribute',
      success: V01::Status.success(:code_200, V01::Entities::CustomAttribute),
      failure: V01::Status.failures(override: {code_404: 'CustomAttribute found.'})
    params do
      requires :id, type: Integer
    end
    get ':id' do
      custom_attribute = current_customer.custom_attributes.where(id: params[:id]).first
      if custom_attribute
        present custom_attribute, with: V01::Entities::CustomAttribute
        return
      end
      error! V01::Status.code_response(:code_404, before: 'CustomAttribute'), 404
    end

    desc 'Update custom_attribute.',
      nickname: 'updateCustomAttribute',
      success: V01::Status.success(:code_200, V01::Entities::CustomAttribute),
      failure: V01::Status.failures(override: {code_404: 'CustomAttribute not found.' })
    params do
      requires :id, type: Integer

      use :params_from_entity, entity: V01::Entities::CustomAttribute.documentation.except(
          :id,
          :name,
          :object_type,
          :object_class,
          :default_value,
          :description)
    end
    put ':id' do
      custom_attribute = current_customer.custom_attributes.where(id: params[:id]).first
      if custom_attribute
        custom_attribute.update! custom_attribute_params
        present custom_attribute, with: V01::Entities::CustomAttribute
        return
      end
      error! V01::Status.code_response(:code_404, before: 'CustomAttribute'), 404
    end

    desc 'Create custom_attribute.',
      nickname: 'CreateCustomAttribute',
      success: V01::Status.success(:code_200, V01::Entities::CustomAttribute),
      failure: V01::Status.failures
    params do
      use :params_from_entity, entity: V01::Entities::CustomAttribute.documentation.except(:id)
    end
    post do
      custom_attribute = current_customer.custom_attributes.build(custom_attribute_params)
      custom_attribute.save!
      current_customer.save!
      present custom_attribute, with: V01::Entities::CustomAttribute
    end

    desc 'Delete custom_attribute.',
      nickname: 'deleteCustomAttribute',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    delete ':id' do
      id = ParseIdsRefs.read(params[:id])
      current_customer.custom_attributes.where(id).first!.destroy
      status 204
    end
  end
end
