class V100::Entities::Destination < Grape::Entity
  def self.entity_name
    'V100_Destination'
  end

  expose(:id, documentation: { type: Integer })
  expose(:ref, documentation: { type: String })
  expose(:name, documentation: { type: String })
  expose(:street, documentation: { type: String })
  expose(:postalcode, documentation: { type: String })
  expose(:city, documentation: { type: String })
  expose(:state, documentation: { type: String })
  expose(:country, documentation: { type: String })
  expose(:lat, documentation: { type: Float })
  expose(:lng, documentation: { type: Float })
  expose(:detail, documentation: { type: String })
  expose(:comment, documentation: { type: String })
  expose(:phone_number, documentation: { type: String })
  expose(:geocoding_accuracy, documentation: { type: Float })
  expose(:geocoding_level, documentation: { type: String, values: ['point', 'house', 'street', 'intersection', 'city'] })
  expose(:geocoding_result, documentation: { type: JSON })
  expose(:geocoded_at, documentation: { type: DateTime})
  expose(:geocoder_version, documentation: {type: String})
  expose(:duration, documentation: { type: DateTime, desc: 'Destination duration.' })
end

class V100::Entities::DestinationWithVisit < V100::Entities::Destination
  def self.entity_name
    'V100_DestinationWithVisit'
  end

  expose(:visits, using: V100::Entities::Visit, documentation: { type: V100::Entities::Visit, is_array: true })
end
