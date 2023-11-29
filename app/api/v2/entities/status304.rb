class V2::Entities::Status304 < Grape::Entity
  def self.entity_name
    'V2_Status304'
  end

  expose(:detail, documentation: { type: String, desc: 'Server rendered details', values: ['304 : to be defined'] })
end
