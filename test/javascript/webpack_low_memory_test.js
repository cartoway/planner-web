'use strict';

// Happy path: WEBPACK_LOW_MEMORY=1 sets webpack parallelism to 1 (lower peak RAM).
process.env.WEBPACK_LOW_MEMORY = '1';
process.env.NODE_ENV = 'production';

const config = require('../../config/webpack/production');

if (config.parallelism !== 1) {
  console.error('expected parallelism === 1, got', config.parallelism);
  process.exit(1);
}

console.log('ok: WEBPACK_LOW_MEMORY sets parallelism=1');
