class V100::Entities::StopStatus < Grape::Entity
  def self.entity_name
    'V100_StopStatus'
  end

  STOP_TYPES = { StopVisit: 'visit', StopStore: 'reload', StopRest: 'rest' }.freeze

  expose(:id, documentation: { type: Integer })
  expose(:index, documentation: { type: Integer, desc: 'Stop\'s Index' })
  expose(:stop_type, documentation: { type: String, desc: 'Type of stop: visit, reload or rest.' }) { |stop| STOP_TYPES[stop.class.name.to_sym] }
end
