class V100::Entities::Job < Grape::Entity
  def self.entity_name
    'V100_Job'
  end

  expose(:message, documentation: { type: String }, if: lambda { |_m, options| options[:message] }) { |_m, options|
    options[:message]
  }
  expose(:id, documentation: { type: Integer, desc: 'Delayed job id. Poll GET /jobs/:id until status is succeeded or failed.', example: 88 })
  expose(:status, documentation: { type: String, values: %w[running failed succeeded], desc: 'running or failed while the Delayed::Job row exists; succeeded after successful completion.' }) { |m|
    if m.respond_to?(:failed_at)
      m.failed_at ? 'failed' : 'running'
    else
      m.status
    end
  }
  expose(:type, documentation: { type: String, desc: 'Job kind derived from the class name: optimizer, geocoder, geocoder_stores.', example: 'optimizer' }) { |m|
    if m.respond_to?(:name)
      m.name.to_s.underscore.parameterize(separator: '_').gsub(/_job$/, '')
    else
      m.type
    end
  }
  expose(:attempts, documentation: { type: Integer }, if: lambda { |m, _| m.respond_to?(:attempts) })
  expose(:created_at, documentation: { type: Date }, if: lambda { |m, _| m.respond_to?(:created_at) })
  expose(:failed_at, documentation: { type: Date }, if: lambda { |m, _| m.respond_to?(:failed_at) })
  expose(:locked_at, documentation: { type: Date }, if: lambda { |m, _| m.respond_to?(:locked_at) })
  expose(:progress, documentation: { type: JSON }, if: lambda { |m, _| m.respond_to?(:progress) })
  expose(:run_at, documentation: { type: Date }, if: lambda { |m, _| m.respond_to?(:run_at) })
  expose(:finished_at, documentation: { type: DateTime, desc: 'Set when status is succeeded.' }, if: lambda { |m, _| m.respond_to?(:finished_at) && m.finished_at })
end
