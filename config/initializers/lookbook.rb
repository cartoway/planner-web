# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless defined?(Lookbook)

  # Standalone layout avoids v2 @reseller / full app chrome while matching BS5 + typography overrides.
  Lookbook.config.preview_layout = 'lookbook_preview'
end
