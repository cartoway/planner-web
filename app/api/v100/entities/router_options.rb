class V100::Entities::RouterOptions < Grape::Entity
  def self.entity_name
    'V100_RouterOptions'
  end

  # expose(:traffic, documentation: { type: 'Boolean' }) { |m| m['traffic'] }
  expose(:track, documentation: { type: 'Boolean' }) { |m| m['track'] }
  expose(:motorway, documentation: { type: 'Boolean' }) { |m| m['motorway'] }
  expose(:toll, documentation: { type: 'Boolean' }) { |m| m['toll'] }
  expose(:trailers, documentation: { type: Integer }) { |m| m['trailers'] }
  expose(:weight, documentation: { type: Float, desc: 'Total weight with trailers and shipping goods, in tons' }) { |m| m['weight'] }
  expose(:weight_per_axle, documentation: { type: Float }) { |m| m['weight_per_axle'] }
  expose(:height, documentation: { type: Float }) { |m| m['height'] }
  expose(:width, documentation: { type: Float }) { |m| m['width'] }
  expose(:length, documentation: { type: Float }) { |m| m['length'] }
  expose(:hazardous_goods, documentation: { type: String, values: %w(explosive gas flammable combustible organic poison radio_active corrosive poisonous_inhalation harmful_to_water other)}) { |m| m['hazardous_goods'] }
  expose(:max_walk_distance, documentation: { type: Float }) { |m| m['max_walk_distance'] }
  expose(:approach, documentation: { type: String, values: ['unrestricted', 'curb'] })
  expose(:snap, documentation: { type: Float }) { |m| m['snap'] }
  expose(:strict_restriction, documentation: { type: 'Boolean' }) { |m| m['strict_restriction'] }
end
