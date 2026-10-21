# frozen_string_literal: true

require_relative '../test_split'

module TestSplitRake
  module_function

  def run_partition(files, suite:)
    abort "test:#{suite}: no test files matched" if files.empty?

    all = TestSplit.all_test_files
    abort "test:#{suite}: partition equals full suite (#{files.size} files) — refusing" if files.size == all.size

    other = suite == 'frontend' ? TestSplit.backend_test_files : TestSplit.frontend_test_files
    overlap = files & other
    abort "test:#{suite}: overlap with other partition: #{overlap.first(5).join(', ')}" if overlap.any?

    test_dir = Rails.root.join('test').to_s
    $LOAD_PATH.unshift(test_dir) unless $LOAD_PATH.include?(test_dir)

    # Require only this partition. Do not use Rails::TestUnit::Runner.rake_run:
    # an empty/misparsed pattern list falls back to test/**/*_test.rb (full suite).
    files.each { |path| require Rails.root.join(path).to_s }

    $stdout.sync = true
    warn "test:#{suite}: #{files.size} files (#{all.size - files.size} in other partition)"

    ARGV.clear
    require 'active_support/testing/autorun'
  end
end


namespace :test do
  desc 'Run frontend minitests (views/helpers/components + assert_select files)'
  task frontend: 'test:prepare' do
    TestSplitRake.run_partition(TestSplit.frontend_test_files, suite: 'frontend')
  end

  desc 'Run backend minitests (everything except frontend partition)'
  task backend: 'test:prepare' do
    TestSplitRake.run_partition(TestSplit.backend_test_files, suite: 'backend')
  end
end
