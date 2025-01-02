# Limit directory being watched
directories %w(app db config lib test)
# Clear console when launching guard
clearing :on
# Display notification in OS
# notification :libnotify, timeout: 5, transient: true, append: false, urgency: :critical
notification :off
# Don't display a pry console
interactor :off

group :server do
  guard 'migrate' do
    watch(%r{^db/migrate/(\d+).+\.rb})
  end

  # Option "force_run: true" does not work on Windows
  guard :rails, port: 8080, timeout: 60 do
    # watch(%r{^Gemfile\.lock$})
    watch(%r{^app/api/(.+)\.rb})
    watch(%r{^app/jobs/(.+)\.rb})
    watch(%r{^config/.+(?<!locales)/.*})
    watch(%r{^config/*/[^.][^/]+\.(rb|yml)(?<!i18n-js\.yml)})
    watch(%r{^lib/.*})
  end
end

guard 'process', name: 'Webpacker', command: './bin/webpack-dev-server' do
  watch(%r{^config/.+(?<!locales)/.*})
  watch(%r{^config/*/[^.][^/]+\.(rb|yml)(?<!i18n-js\.yml)})
end

# guard 'delayed', number_of_workers: 2, environment: 'development' do
#   watch(%r{^app/jobs/(.+)\.rb})
#   watch(%r{^app/models/(.+)\.rb})
#   watch(%r{^config/initializers/.+\.rb})
# end

# guard 'process', name: 'i18n-js', command: 'rake i18n:js:export' do
#   watch(%r{^config/i18n-js\.yml})
#   watch(%r{^config/locales/js\..+\.yml})
# end

# guard :minitest do
#   watch(%r{^test/(.*)\/?test_(.*)\.rb$})
#   watch(%r{^lib/(.*/)?([^/]+)\.rb$})     { |m| "test/#{m[1]}test_#{m[2]}.rb" }
#   watch(%r{^test/test_helper\.rb$})      { 'test' }
# end
