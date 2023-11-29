class V2::Entities::Status400 < Grape::Entity
  def self.entity_name
    'V2_Status400'
  end

  expose(:message, documentation: { type: String, desc: 'Error messages.', values: ["Validation failed: Customers profile can't be blank, Customers router can't be blank, Customers router unauthorized in this profile, Customers max vehicles must be greater than 0"] })
  expose(:status, documentation: { type: Integer, desc: 'Error code.', values: [400] })
end
