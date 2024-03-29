class V100::Entities::Status204 < Grape::Entity
  def self.entity_name
    'V100_Status204'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['No content.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [204] })
end
