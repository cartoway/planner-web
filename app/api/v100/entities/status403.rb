class V100::Entities::Status403 < Grape::Entity
  def self.entity_name
    'V100_Status403'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Forbidden : admin account required.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [403] })
end
