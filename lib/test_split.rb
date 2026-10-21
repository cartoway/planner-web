# frozen_string_literal: true

# Partition minitest files into frontend (render/markup/JS) vs backend.
module TestSplit
  FRONTEND_DIRS = %w[
    test/views
    test/helpers
    test/components
    test/assets
    test/javascript
    test/controllers/lookbook
    test/services/lookbook
  ].freeze

  FRONTEND_FILES = %w[
    test/integration/lookbook_mount_test.rb
    test/lib/schedule_time_js_test.rb
    test/service_worker_photos_test.rb
  ].freeze

  ASSERT_SELECT_RE = /\bassert_(select|dom)\b/

  module_function

  def all_test_files(root: Dir.pwd)
    Dir.chdir(root) { Dir['test/**/*_test.rb'] }.sort
  end

  def frontend_test_files(root: Dir.pwd)
    Dir.chdir(root) do
      from_dirs = FRONTEND_DIRS.flat_map { |d| Dir["#{d}/**/*_test.rb"] }
      from_assert = Dir['test/**/*_test.rb'].select do |path|
        File.read(path).match?(ASSERT_SELECT_RE)
      end
      (from_dirs + FRONTEND_FILES + from_assert).uniq.sort
    end
  end

  def backend_test_files(root: Dir.pwd)
    (all_test_files(root: root) - frontend_test_files(root: root)).sort
  end
end
