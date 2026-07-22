# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'
Rails.application.config.assets.unknown_asset_fallback = true

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Importmap (v2): allow path_to_asset / digest for every ESM file under app/javascript and vendor/javascript.
# Otherwise Sprockets raises AssetNotPrecompiledError and the browser falls back to /controllers/... (HTML, wrong MIME).
Rails.application.config.assets.precompile << lambda do |_logical_path, filename|
  next false unless filename

  fn = filename.to_s
  [
    Rails.root.join('app', 'javascript').to_s,
    Rails.root.join('vendor', 'javascript').to_s
  ].any? { |root| fn.start_with?("#{root}/") }
end

# V2: post-Bootstrap overrides (must bypass debug: split mode — otherwise AV falls back to /stylesheets/… 404 + wrong MIME).
Rails.application.config.assets.precompile += %w[v2/application.css v2/layout_bootstrap_overrides.css lookbook_preview.css]
