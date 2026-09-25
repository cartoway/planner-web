# Minimum versions aligned with native Import Maps support (required by Hotwire/importmap on v2):
# Chrome 89+, Edge 89+, Firefox 108+, Safari 16.4+, Opera 76+ — see https://caniuse.com/import-maps
# Electron 12+ ships Chromium 89.
def modern_browser?(browser)
  [
    browser.electron?(">= 12"),
    browser.chrome?(">= 89"),
    browser.safari?(">= 16.4"),
    browser.firefox?(">= 108"),
    browser.edge?(">= 89"),
    browser.opera?(">= 76"),
    browser.facebook? && browser.safari_webapp_mode? && browser.safari?(">= 16.4")
  ].any?
end

Rails.configuration.middleware.use Browser::Middleware do
  if !modern_browser?(browser) &&
     !request.env['PATH_INFO'].start_with?('/api/') &&
     !request.env['PATH_INFO'].start_with?('/lookbook') &&
     request.env['PATH_INFO'] != '/up' &&
     (!request.env['QUERY_STRING'] || !request.env['QUERY_STRING'].include?('disposition=inline'))
    redirect_to unsupported_browser_path(browser: :modern)
  end
end
