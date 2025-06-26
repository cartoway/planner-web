class V100::Entities::Job < Grape::Entity
  def self.entity_name
    'V100_Job'
  end

  expose(:message, documentation: { type: String }, if: lambda { |m, options| m || options[:message] }) { |m, options|
    options[:message] || m
  }
  expose(:id, documentation: { type: Integer })
  expose(:attempts, documentation: { type: Integer })
  expose(:created_at, documentation: { type: Date })
  expose(:failed_at, documentation: { type: Date })
  expose(:locked_at, documentation: { type: Date })
  expose(:progress, documentation: { type: JSON })
  expose(:run_at, documentation: { type: Date })
  expose(:type, documentation: { type: String }) { |m|
    m.name.underscore.parameterize(separator: '_').gsub(/_job$/, '')
  }
end
