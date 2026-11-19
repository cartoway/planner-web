# frozen_string_literal: true

# Happy-path check: locale leak from RouterTest-style default_locale swap is restored,
# so French comma decimals keep working.

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Reproduce RouterTest#test_should_translate_name leak without DB.
I18n.default_locale = :en
I18n.with_locale(:fr) { nil }
I18n.with_locale(:en) { nil }
I18n.default_locale = :fr
abort("expected leaked locale :en, got #{I18n.locale.inspect}") unless I18n.locale == :en

# Same reset as test_helper setup/teardown.
I18n.locale = I18n.default_locale = :fr
abort("expected restored locale :fr, got #{I18n.locale.inspect}") unless I18n.locale == :fr
abort("expected 12.3 from '12,3'") unless (CoerceFloatString.parse('12,3') - 12.3).abs < 0.0001

puts 'OK: I18n locale reset restores French comma decimals'
