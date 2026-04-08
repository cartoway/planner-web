require 'test_helper'

require 'i18n/tasks'

class I18nTest < ActiveSupport::TestCase
  test 'should not have missing keys' do
    translation = I18n::Tasks::BaseTask.new(locales: [:en, :fr])
    missing_keys = translation.missing_keys
    # unused_keys = translation.unused_keys

    if missing_keys.leaves.count > 0
      # require 'i18n/tasks/cli'
      #
      # I18n.with_locale 'en' do
      #   I18n::Tasks::CLI.new.run(['health'])
      # end

      ap missing_keys.leaves
    end

    assert_equal 0, missing_keys.leaves.count
  end
end
