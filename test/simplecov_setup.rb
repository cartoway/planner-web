# frozen_string_literal: true

# Shared SimpleCov config for full suite runs, partitions (TEST_SUITE), and coverage:collate.
module SimplecovSetup
  MINIMUM = 84
  ROOT = File.expand_path('..', __dir__)

  module_function

  def enabled?
    (!ENV.key?('COV') && !ENV.key?('COVERAGE')) ||
      (ENV['COV'] != 'false' && ENV['COVERAGE'] != 'false')
  end

  def suite
    name = ENV['TEST_SUITE'].to_s
    %w[frontend backend].include?(name) ? name : nil
  end

  def start!
    return unless enabled?

    require 'fileutils'
    require 'simplecov'

    # Preserve argv before rake/webpack mutate it; rake test otherwise falls back to "RSpec".
    SimpleCov::CommandGuesser.original_run_command ||= [$0, *ARGV].join(' ')

    coverage_rel = suite ? "coverage/#{suite}" : 'coverage'
    coverage_abs = File.join(ROOT, coverage_rel)
    FileUtils.mkdir_p(coverage_abs)
    FileUtils.rm_f(File.join(coverage_abs, '.resultset.json'))
    FileUtils.rm_f(File.join(coverage_abs, '.resultset.json.lock'))

    SimpleCov.coverage_dir coverage_rel

    if suite
      SimpleCov.command_name "rails test:#{suite}"
      # Partial partition — threshold enforced by `rake coverage:collate`.
    else
      command = SimpleCov::CommandGuesser.guess
      command = 'rails test' if ['RSpec', 'Unknown Test Framework'].include?(command)
      SimpleCov.command_name(command)
      SimpleCov.minimum_coverage MINIMUM
    end

    SimpleCov.start 'rails' do
      SimplecovSetup.apply_common!(self)
    end
  end

  def collate!
    require 'simplecov'

    files = Dir[File.join(ROOT, 'coverage', '*', '.resultset.json')]
    if files.empty?
      found = Dir[File.join(ROOT, 'coverage', '**', '*')].reject { |p| File.directory?(p) }
      abort "coverage:collate: no resultsets under coverage/*/ (found: #{found.inspect})"
    end

    SimpleCov.collate(files, 'rails') do
      SimplecovSetup.apply_common!(self)
      minimum_coverage SimplecovSetup::MINIMUM
    end
  end

  def apply_common!(cov)
    cov.root ROOT
    # Rails profile scans all lib/**/*.rb on disk (track_files), which inflates the
    # denominator with 0%-lines that never merge with runtime hits on boot-loaded files.
    cov.track_files 'app/**/*.rb'

    # Lookbook / design-system tooling — not part of planner runtime coverage.
    # Match both absolute CI paths and SimpleCov project_filename (no leading slash).
    cov.add_filter do |source_file|
      path = "#{source_file.filename} #{source_file.project_filename}"
      path.match?(%r{app/services/lookbook/}) ||
        path.match?(%r{app/controllers/lookbook/}) ||
        path.match?(%r{lib/lookbook_haml_to_erb}) ||
        path.match?(%r{config/initializers/lookbook\.rb}) ||
        path.match?(%r{app/services/lookbook_dual_format_template_resolver\.rb}) ||
        path.match?(%r{script/.+lookbook}i)
    end
  end
end
