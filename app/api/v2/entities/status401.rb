class V2::Entities::Status401 < Grape::Entity
  def self.entity_name
    'V2_Status401'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Unauthorized : authentification required.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [401] })
end
