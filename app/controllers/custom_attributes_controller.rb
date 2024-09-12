class CustomAttributesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_custom_attribute, only: [:edit, :update, :destroy, :update_default_value_partial]

  load_and_authorize_resource

  def index
    @custom_attributes = current_user.customer.custom_attributes
  end

  def new
    @custom_attribute = current_user.customer.custom_attributes.build(object_class: 2)
  end

  def edit; end

  def create
    respond_to do |format|
      CustomAttribute.transaction do
        @custom_attribute = current_user.customer.custom_attributes.build(custom_attribute_params)
        if current_user.customer.save
          format.html { redirect_to custom_attributes_path, notice: t('activerecord.successful.messages.created', model: @custom_attribute.class.model_name.human) }
        else
          format.html { render action: 'new' }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @custom_attribute.update(custom_attribute_params) && @custom_attribute.customer.save
        format.html { redirect_to custom_attributes_path, notice: t('activerecord.successful.messages.updated', model: @custom_attribute.class.model_name.human) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def update_default_value_partial
    @object_type = params[:custom_attribute][:object_type]
    @typed_default_value = helpers.object_type_cast(params[:custom_attribute][:object_type], @custom_attribute.default_value)
    respond_to do |format|
      format.js { render partial: 'update_default_value' }
    end
  end

  def reset_default_value_partial
    @object_type = params[:custom_attribute][:object_type]
    @typed_default_value = @object_type == 'array' ? [''] : nil
    respond_to do |format|
      format.js { render partial: 'update_default_value' }
    end
  end

  def destroy
    @custom_attribute && current_user.customer.custom_attributes.delete(@custom_attribute) && current_user.customer.save
    respond_to do |format|
      format.html { redirect_to custom_attributes_url }
    end
  end

  def destroy_multiple
    CustomAttribute.transaction do
      if params['custom_attributes']
        ids = params['custom_attributes'].keys.collect{ |i| Integer(i) }
        current_user.customer.custom_attributes.select{ |custom_attribute| ids.include?(custom_attribute.id) }.each(&:destroy)
        current_user.customer.save
      end
      respond_to do |format|
        format.html { redirect_to custom_attributes_url }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_custom_attribute
    @custom_attribute = current_user.customer.custom_attributes.find params[:id] || params[:custom_attribute_id]
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def custom_attribute_params
    params.require(:custom_attribute).permit(:name, :object_type, :object_class, :default_value, :description, :customer_id, default_value: [])
  end
end
