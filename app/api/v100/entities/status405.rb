class V100::Entities::Status405 < Grape::Entity
  def self.entity_name
    'V100_Status405'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Method not allowed on the resource.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [405] })
end
