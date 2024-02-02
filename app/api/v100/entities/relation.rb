class V100::Entities::Relation < Grape::Entity
  def self.entity_name
    'V100_Relation'
  end

  expose(:id, documentation: { type: Integer})
  expose(:relation_type, documentation: { type: String })
  expose(:current_id, documentation: { type: Integer })
  expose(:successor_id, documentation: { type: Integer })
end
