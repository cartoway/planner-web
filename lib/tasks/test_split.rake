# frozen_string_literal: true

require_relative '../test_split'
require 'rails/test_unit/runner'

namespace :test do
  desc 'Run frontend minitests (views/helpers/components + assert_select files)'
  task frontend: 'test:prepare' do
    test_dir = Rails.root.join('test').to_s
    $LOAD_PATH.unshift(test_dir) unless $LOAD_PATH.include?(test_dir)

    files = TestSplit.frontend_test_files
    abort 'test:frontend: no test files matched' if files.empty?

    Rails::TestUnit::Runner.rake_run(files)
  end

  desc 'Run backend minitests (everything except frontend partition)'
  task backend: 'test:prepare' do
    test_dir = Rails.root.join('test').to_s
    $LOAD_PATH.unshift(test_dir) unless $LOAD_PATH.include?(test_dir)

    files = TestSplit.backend_test_files
    abort 'test:backend: no test files matched' if files.empty?

    Rails::TestUnit::Runner.rake_run(files)
  end
end
