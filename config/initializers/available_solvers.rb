require 'yaml'

config_path = Rails.root.join('config', 'available_solvers.yml')
if File.exist?(config_path)
  solvers_config = YAML.load_file(config_path)
  env_config = solvers_config[Rails.env] || {}
  solvers = env_config['solvers'] || []
else
  solvers = []
end

if ENV['AVAILABLE_SOLVERS'].present?
  solvers = ENV['AVAILABLE_SOLVERS'].split(',').map(&:strip)
end

Rails.application.config.available_solvers = solvers
