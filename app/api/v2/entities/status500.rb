class V2::Entities::Status500 < Grape::Entity
  def self.entity_name
    'V2_Status500'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Internal Server Error.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [500] })
end
