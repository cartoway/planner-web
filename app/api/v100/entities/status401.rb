class V100::Entities::Status401 < Grape::Entity
  def self.entity_name
    'V100_Status401'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Unauthorized : authentification required.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [401] })
end
