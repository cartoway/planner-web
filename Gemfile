source 'https://rubygems.org'
ruby '~> 3'


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1', '>= 6.1.7.8'
gem 'railties', '~> 6.1', '>= 6.1.7.8'

gem 'bootsnap'
# Allow haml syntax for views
gem 'haml-rails'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '< 4.0' # TODO: fixme with use strict functions should be declared at top level
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks', '< 5' # FIXME: turbolinks not working with anchors in url
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'
# bundle exec rake doc:rails generates the API under doc/api.
# gem 'sdoc', group: :doc

gem 'rake'

# Make hashes more powerful
gem 'hashie'

gem 'puma'
gem 'mail'
gem 'net-ftp'

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2' # FIXME: require Rails 5

  # Improve error interaction
  gem 'better_errors'
  gem 'binding_of_caller'

  # Preview emails
  gem 'letter_opener_web'

  if respond_to?(:install_if)
    # Install only for ruby >=2.2
    install_if lambda { Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2') } do
      # Guard with plugins
      gem 'guard'
      gem 'guard-rails'
      gem 'guard-migrate'
      gem 'guard-rake'
      gem 'guard-delayed'
      gem 'guard-process'
      gem 'libnotify'
    end
  end
end

group :development, :test do
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # gem 'spring' # Other gems incmpatible with last spring version

  gem 'erb_lint'
  gem 'rubocop'
  gem 'byebug'
  gem 'i18n-tasks'

  # Debugging tool
  gem 'pry-rails'
  gem 'awesome_print'

  gem 'brakeman'
  gem 'bundler-audit'
  gem 'figaro'
end

group :test do
  gem 'minitest-focus'
  gem 'minitest-around'
  gem 'minitest-stub_any_instance'
  gem 'minitest-reporters'
  gem 'mocha'
  gem 'simplecov', require: false
  gem 'webmock'
  gem 'tidy-html5', git: 'https://github.com/moneyadviceservice/tidy-html5-gem.git'
  gem 'html_validation'

  gem 'rails-controller-testing'
  gem 'rspec-rails'

  # Browser tests
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end

gem 'bullet'  # Used in production for api-web doc generation
gem 'rails_performance'

gem 'sys-filesystem'
gem 'sys-cpu'
gem 'get_process_mem'

gem 'grape'
gem 'grape-entity'
gem 'grape-swagger'
gem 'grape-swagger-entity'
gem 'rack-cors'
gem 'rswag-api'
gem 'rswag-specs'
gem 'grape_logging'

gem 'rails-i18n', '>= 7'
gem 'http_accept_language'
gem 'devise'
gem 'devise-i18n'
gem 'devise-i18n-views'
gem 'cancancan'
gem 'lograge'
gem 'validates_timeliness'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter'

gem 'sanitize'
gem 'iconv'

gem 'pg'

gem 'sprockets'

gem 'webpacker'

gem "font-awesome-sass", "~> 6.4.2"
gem 'twitter-bootstrap-rails'
gem 'bootstrap_form'
gem 'bootstrap-wysihtml5-rails', "< 0.3.3.5" # CVE-2019-19919
gem 'bootstrap-datepicker-rails'

gem 'leaflet-rails', '> 1.0.2'
gem 'leaflet-markercluster-rails', git: 'https://github.com/Mapotempo/leaflet-markercluster-rails.git' # FIXME wait for https://github.com/scpike/leaflet-markercluster-rails/pull/8
gem 'leaflet-draw-rails', git: 'https://github.com/frodrigo/leaflet-draw-rails.git' # FIXME wait for https://github.com/zentrification/leaflet-draw-rails/pull/1
gem 'leaflet_numbered_markers-rails', git: 'https://github.com/frodrigo/leaflet_numbered_markers-rails.git'
gem 'leaflet-control-geocoder-rails', git: 'https://github.com/Mapotempo/leaflet-control-geocoder-rails.git'
gem 'leaflet-controlledbounds-rails', git: 'https://github.com/Mapotempo/leaflet-controlledbounds-rails.git'
gem 'leaflet-hash-rails', git: 'https://github.com/frodrigo/leaflet-hash-rails.git'
gem 'leaflet-pattern-rails', git: 'https://github.com/Mapotempo/leaflet-pattern-rails.git'
gem 'sidebar-v2-gh-pages-rails', git: 'https://github.com/Mapotempo/sidebar-v2-gh-pages-rails.git'
gem 'leaflet-encoded-rails', git: 'https://github.com/Mapotempo/leaflet-encoded-rails.git'
gem 'leaflet-responsive-popup-rails', git: 'https://github.com/Mapotempo/leaflet-responsive-popup-rails.git'

gem 'jquery-turbolinks'
gem 'jquery-ui-rails', '< 6' # FIXME Support IE10 removed in jQuery UI 1.12 + bad performances for large list sortable
gem 'jquery-tablesorter', '~> 1.27'
gem 'jquery-simplecolorpicker-rails'
gem 'jquery-timeentry-rails', git: 'https://github.com/frodrigo/jquery-timeentry-rails.git'
gem 'select2-rails'
gem 'i18n-js', '< 4'
gem 'mustache'
gem 'smt_rails', '0.2.9' # FIXME: JS not working in 0.3.0
gem 'paloma'
gem 'browser'
gem 'color'
gem 'pagy', '~> 9.1'

gem 'daemons'
gem 'delayed_job'
gem 'delayed_job_active_record'
gem 'delayed_job_web'

gem 'fast-polylines'
gem 'rgeo'
gem 'rgeo-geojson'
gem 'simplify_rb', git: 'https://github.com/cartoway/simplify_rb', branch: 'dev' # Gem simplifying polylines using Douglas-Peucker algorithm

gem 'ai4r'
gem 'sim_annealing'

gem 'nilify_blanks'
gem 'auto_strip_attributes'
gem 'amoeba'
gem 'carrierwave'

gem 'charlock_holmes', '> 0.7.3'
gem 'savon'
gem 'savon-multipart'
gem 'rest-client'
gem 'macaddr'
gem 'rubyzip'
gem 'barby'

gem 'pnotify-rails'

gem 'nokogiri'
gem 'addressable'
gem 'icalendar'

# Format emails, nokogiri is required for premailer
gem 'premailer-rails'

gem 'chronic_duration'

# SMS
gem 'iso_country_codes'
gem 'phonelib'
gem 'vonage', '~> 7.28'

gem 'sentry-ruby'
gem 'sentry-rails'
gem 'sentry-delayed_job'

group :production do
  gem 'redis'
  gem 'redis-store', '~> 1.4.1' # Ensure redis-store dependency is at least 1.4.1 for CVE-2017-1000248 correction
  gem 'redis-rails'
end
