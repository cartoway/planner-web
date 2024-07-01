require 'test_helper'

class MobileHelperTest < ActionView::TestCase
  test 'test multiple user_agents through detect_agent' do
    user_agent =
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36"
    mock_user_agent(user_agent)
    assert_equal :mobile, detect_agent


    # Samsung Galaxy S22 5G
    user_agent =
      "Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    mock_user_agent(user_agent)
    assert_equal :mobile, detect_agent

    # Google Pixel 7
    user_agent =
      "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    mock_user_agent(user_agent)
    assert_equal :mobile, detect_agent

    # Huawei P30 Pro
    user_agent =
      "Mozilla/5.0 (Linux; Android 10; VOG-L29) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    mock_user_agent(user_agent)
    assert_equal :mobile, detect_agent

    # iPhone 12
    user_agent =
      "Mozilla/5.0 (iPhone13,2; U; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) Version/10.0 Mobile/15E148 Safari/602.1"
    mock_user_agent(user_agent)
    assert_equal :ios, detect_agent

    # Apple iPhone 6
    user_agent =
      "Mozilla/5.0 (Apple-iPhone7C2/1202.466; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1A543 Safari/419.3"
    mock_user_agent(user_agent)
    assert_equal :ios, detect_agent

    # Windows 10 - Edge
    user_agent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246"
    mock_user_agent(user_agent)
    assert_equal :standard, detect_agent

    # Ubuntu - Firefox
    user_agent =
      "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:15.0) Gecko/20100101 Firefox/15.0.1"
    mock_user_agent(user_agent)
    assert_equal :standard, detect_agent
  end

  def mock_user_agent(user_agent)
    mock_request = mock('request')
    mock_request.expects(:user_agent).at_least(1).returns(user_agent)

    @controller = mock('controller')
    @controller.stubs(:request).returns(mock_request)
  end
end
