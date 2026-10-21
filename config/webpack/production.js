'use strict';

const environment = require('./environment');

const config = environment.toWebpackConfig();

// Docker image builds (planner-dev-up): serialize compilation to cut peak RAM.
if (process.env.WEBPACK_LOW_MEMORY === '1') {
  config.parallelism = 1;
}

module.exports = config;
