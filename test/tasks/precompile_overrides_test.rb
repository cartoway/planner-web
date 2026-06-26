require 'test_helper'

class PrecompileOverridesTest < ActiveSupport::TestCase
  test 'assets:precompile runs swagger generation after asset compilation' do
    Rails.application.load_tasks

    assert Rake::Task.task_defined?('rswag:specs:swaggerize')

    precompile_task = Rake::Task['assets:precompile']
    assert_operator precompile_task.actions.size, :>=, 2
  end
end
