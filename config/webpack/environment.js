const { environment } = require('@rails/webpacker')
const webpack = require('webpack');
const path = require('path');

const erb = require('./loaders/erb');

environment.loaders.append('erb', erb);

// resolve-url-loader must be used before sass-loader
environment.loaders.get('sass').use.splice(-1, 0, {
  loader: 'resolve-url-loader',
  options: {
    attempts: 1
  }
});
// Vendor stylesheet entry
environment.entry.set('vendor_stylesheet', path.resolve(__dirname, '..', '..', 'app/javascript/packs/vendor_stylesheet.js'));

  // Alias configuration
environment.config.set('resolve.alias', {
  jquery: path.resolve(__dirname, '..', '..', 'node_modules/jquery/src/jquery'),
  pnotify: path.resolve(__dirname, '..', '..', 'node_modules/pnotify')
});

// Add an ProvidePlugin
environment.plugins.append('Provide', new webpack.ProvidePlugin({
    $: 'jquery',
    jQuery: 'jquery',
    L: 'leaflet',
    PNotify: 'pnotify'
  })
);

environment.loaders.prepend('node-modules-css', {
  test: /\.css$/,
  include: /node_modules/,
  use: ['style-loader', 'css-loader']
});

// General CSS loader
environment.loaders.append('css', {
  test: /\.css$/,
  exclude: /node_modules/,
  use: [
    'style-loader',
    'css-loader',
    {
      loader: 'postcss-loader',
      options: {
        postcssOptions: {
          plugins: [
            require('autoprefixer'),
            require('postcss-preset-env')({
              stage: 3,
              features: {
                'nesting-rules': true
              }
            })
          ],
        },
      },
    },
  ],
});

module.exports = environment
