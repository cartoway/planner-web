class V01::Entities::Status408 < Grape::Entity
  def self.entity_name
    'V01_Status408'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Method not allowed on the resource.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [408] })
end
