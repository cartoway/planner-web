// Happy-path check for Tom Select dropdown flip math (keep in sync with lib/tom_select_dropdown_flip.js).
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const src = fs.readFileSync(
  path.join(__dirname, '../../app/javascript/lib/tom_select_dropdown_flip.js'),
  'utf8'
)
const sandbox = { exports: {}, module: { exports: {} } }
vm.runInNewContext(src.replace('export function', 'function') + '\nexports.shouldOpenTomSelectUp = shouldOpenTomSelectUp', sandbox)
const { shouldOpenTomSelectUp } = sandbox.exports

assert.equal(shouldOpenTomSelectUp(300, 100), false, 'enough space below → open down')
assert.equal(shouldOpenTomSelectUp(40, 300), true, 'tight below + room above → open up')
assert.equal(shouldOpenTomSelectUp(40, 20), false, 'more room below than above → stay down')
assert.equal(shouldOpenTomSelectUp(100, 400, 260), true, 'below under preferred max → open up')

console.log('tom_select_dropdown_flip_test: ok')
