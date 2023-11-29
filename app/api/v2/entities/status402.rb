class V2::Entities::Status402 < Grape::Entity
  def self.entity_name
    'V2_Status402'
  end

  expose(:message, documentation: { type: String, desc: 'Server rendered messages.', values: ['Subscription expired : contact your reseller.'] })
  expose(:status, documentation: {type: Integer, desc: 'Error code.', values: [402] })
end
