# frozen_string_literal: true

require 'test_helper'
require 'test_split'

class TestSplitTest < ActiveSupport::TestCase
  test 'frontend and backend partition all minitest files without overlap' do
    all = TestSplit.all_test_files
    frontend = TestSplit.frontend_test_files
    backend = TestSplit.backend_test_files

    assert_predicate frontend, :any?
    assert_predicate backend, :any?
    assert_empty frontend & backend
    assert_equal all, (frontend + backend).sort
  end

  test 'every assert_select file is in the frontend partition' do
    assert_files = TestSplit.all_test_files.select do |path|
      File.read(path).match?(TestSplit::ASSERT_SELECT_RE)
    end

    frontend = TestSplit.frontend_test_files
    missing = assert_files - frontend
    assert_empty missing, "assert_select files missing from frontend: #{missing.join(', ')}"
  end
end
