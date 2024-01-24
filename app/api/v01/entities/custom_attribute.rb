class V01::Entities::CustomAttribute < Grape::Entity
  def self.entity_name
    'V01_CustomAttribute'
  end

  expose(:id, documentation: { type: Integer })
  expose(:name, documentation: { type: String })
  expose(:object_type, documentation: { type: String, values: ['boolean', 'string', 'integer', 'float'] })
  expose(:object_class, documentation: { type: String, values: ['vehicle', 'visit'] })
  expose(:default_value, documentation: { type: String })
  expose(:description, documentation: { type: String })
end
