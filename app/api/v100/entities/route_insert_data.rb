class V100::Entities::RouteInsertData < Grape::Entity
  def self.entity_name
    'V100_RouteProperties'
  end

  expose(:route, with: V100::Entities::Route)
  expose(:index, documentation: { type: Integer })
  expose(:time, documentation: { type: Integer })
  expose(:distance, documentation: { type: Float })
end
