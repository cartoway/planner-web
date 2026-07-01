# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless defined?(Lookbook)

  # Standalone layout avoids v2 @reseller / full app chrome while matching BS5 + typography overrides.
  Lookbook.config.preview_layout = 'lookbook_preview'

  Lookbook.add_panel(:source_haml, 'lookbook/inspector/panels/source_haml', label: 'HAML', hotkey: 'm')
  Lookbook.add_panel(:source_erb, 'lookbook/inspector/panels/source_erb', label: 'ERB', hotkey: 'e')
  Lookbook.remove_panel(:source)

  Lookbook.config.preview_inspector.drawer_panels = %i[source_haml source_erb notes params *]
end
