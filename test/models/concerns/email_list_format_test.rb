# frozen_string_literal: true

require 'test_helper'

class EmailListFormatTest < ActiveSupport::TestCase
  test 'split separates by comma semicolon or horizontal whitespace' do
    assert_equal %w[a@b.com c@d.com e@f.com],
                 EmailListFormat.split('a@b.com, c@d.com; e@f.com')
  end

  test 'split rejects blanks' do
    assert_equal %w[a@b.com], EmailListFormat.split('  a@b.com  ,  ')
  end

  test 'valid_list accepts single and multi emails' do
    assert EmailListFormat.valid_list?(nil)
    assert EmailListFormat.valid_list?('')
    assert EmailListFormat.valid_list?('client@example.com')
    assert EmailListFormat.valid_list?('a@b.com, c@d.fr')
    assert EmailListFormat.valid_list?('a@b.com;c@d.fr')
  end

  test 'valid_list rejects invalid addresses' do
    assert_not EmailListFormat.valid_list?('not-an-email')
    assert_not EmailListFormat.valid_list?('a@b')
  end

  test 'valid_list rejects header injection and xss-ish local parts' do
    assert_not EmailListFormat.valid_list?("a@b.com\nBcc:evil@x.co")
    assert_not EmailListFormat.valid_list?("a@b.com\r\nCc:evil@x.co")
    assert_not EmailListFormat.valid_list?('"><img@x.co')
    assert_not EmailListFormat.valid_list?('foo<script>@x.co')
  end
end
