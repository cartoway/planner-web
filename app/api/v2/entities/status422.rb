class V2::Entities::Status422 < Grape::Entity
  def self.entity_name
    'V2_Status422'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Unprocessable entity.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [422] })
end
