def modern_browser?(browser)
  [
    browser.chrome?(">= 45"),
    browser.safari?(">= 10"),
    browser.firefox?(">= 52"),
    browser.edge?(">= 16"),
    browser.opera?(">= 50"),
    browser.facebook? && browser.safari_webapp_mode? && browser.webkit_full_version.to_i >= 602
  ].any?
end

Rails.configuration.middleware.use Browser::Middleware do
  if !modern_browser?(browser) &&
     !request.env['PATH_INFO'].start_with?('/api/') &&
     request.env['PATH_INFO'] != '/up' &&
     (!request.env['QUERY_STRING'] || !request.env['QUERY_STRING'].include?('disposition=inline'))
    redirect_to unsupported_browser_path(browser: :modern)
  end
end
