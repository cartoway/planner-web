class V100::Entities::Status304 < Grape::Entity
  def self.entity_name
    'V100_Status304'
  end

  expose(:detail, documentation: { type: String, desc: 'Server rendered details', values: ['304 : to be defined'] })
end
