class V100::Entities::Status409 < Grape::Entity
  def self.entity_name
    'V100_Status409'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Conflict between several resources.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [409] })
end
