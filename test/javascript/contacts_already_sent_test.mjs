import assert from 'node:assert/strict'
import {
  channelForAlreadySentRow,
  effectiveAlreadySent,
  normalizeContact
} from '../../app/javascript/lib/contacts_already_sent.js'

assert.equal(normalizeContact('  a@b.c  '), 'a@b.c')

assert.equal(effectiveAlreadySent({
  wasSent: true,
  originalEmail: 'a@b.c',
  originalPhone: '0600000000',
  email: 'a@b.c',
  phone: '0600000000'
}), true)

assert.equal(effectiveAlreadySent({
  wasSent: true,
  originalEmail: 'a@b.c',
  originalPhone: '0600000000',
  email: 'other@b.c',
  phone: '0600000000'
}), false)

assert.equal(effectiveAlreadySent({
  wasSent: false,
  originalEmail: 'a@b.c',
  originalPhone: '',
  email: 'a@b.c',
  phone: ''
}), false)

assert.equal(channelForAlreadySentRow({
  alreadySent: true,
  includeAlreadySent: false,
  defaultChannel: 'email'
}), 'none')

assert.equal(channelForAlreadySentRow({
  alreadySent: true,
  includeAlreadySent: true,
  defaultChannel: 'sms'
}), 'sms')

assert.equal(channelForAlreadySentRow({
  alreadySent: false,
  includeAlreadySent: false,
  defaultChannel: 'email'
}), 'email')

console.log('contacts_already_sent ok')
