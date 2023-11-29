class V2::Entities::Status404 < Grape::Entity
  def self.entity_name
    'V2_Status404'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Resource not found.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [404] })
end
