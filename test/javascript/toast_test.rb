# frozen_string_literal: true

require 'test_helper'
require 'shellwords'
require 'fileutils'

class ToastTest < ActiveSupport::TestCase
  test 'showToast accepts className and message' do
    Dir.mktmpdir do |dir|
      FileUtils.cp(Rails.root.join('app/javascript/lib/toast.js'), File.join(dir, 'toast.mjs'))
      check = File.join(dir, 'check.mjs')
      File.write(check, <<~JS)
        import { showToast, clearToasts, toastStack } from './toast.mjs'

        const assert = (cond, msg) => { if (!cond) { console.error(msg); process.exit(1) } }

        function el (tag, attrs = {}) {
          const node = {
            localName: tag.toLowerCase(),
            attributes: { ...attrs },
            children: [],
            parent: null,
            textContent: '',
            className: '',
            style: {},
            getAttribute (name) { return this.attributes[name] ?? null },
            setAttribute (name, value) { this.attributes[name] = String(value) },
            hasAttribute (name) { return Object.prototype.hasOwnProperty.call(this.attributes, name) },
            appendChild (child) { child.parent = this; this.children.push(child); return child },
            querySelector (sel) {
              if (sel === '[data-v2-toast-stack]') return this._stack || null
              return null
            },
            querySelectorAll (sel) {
              if (sel !== '[data-v2-toast]' || !this._stack) return []
              return this._stack.children.filter((c) => c.attributes && 'data-v2-toast' in c.attributes)
            },
            remove () {
              if (!this.parent) return
              this.parent.children = this.parent.children.filter((c) => c !== this)
            },
            addEventListener () {}
          }
          Object.keys(attrs).forEach((k) => {
            node.setAttribute(k, attrs[k])
            if (k === 'class') node.className = attrs[k]
          })
          return node
        }

        const body = el('body')
        const doc = el('document')
        doc.body = body
        doc.documentElement = el('html')
        doc.createElement = (tag) => el(tag)
        body.appendChild = (child) => {
          if (child.attributes && 'data-v2-toast-stack' in child.attributes) doc._stack = child
          child.parent = body
          body.children.push(child)
          return child
        }

        const timers = []
        globalThis.window = { setTimeout: (fn, ms) => { timers.push({ fn, ms }); return timers.length } }

        const success = showToast({ message: 'Saved', className: 'alert-success' }, doc)
        assert(success.className.includes('alert-success'), 'success class')
        assert(success.className.includes('v2-toast'), 'toast marker class')
        assert(success.children[0].textContent === 'Saved', 'message text')
        assert(timers.length === 1 && timers[0].ms === 6000, 'auto-dismiss delay')

        const danger = showToast({ message: 'Boom', className: 'danger', sticky: true }, doc)
        assert(danger.className.includes('alert-danger'), 'shorthand danger → alert-danger')
        assert(timers.length === 1, 'sticky skips timer')

        assert(toastStack(doc) === doc._stack, 'reuses stack')
        assert(doc._stack.children.length === 2, 'stacks toasts')

        clearToasts(doc)
        assert(doc._stack.children.length === 0, 'clears toasts')

        console.log('ok')
      JS
      out = `node #{Shellwords.escape(check)}`
      assert_match(/ok/, out)
    end
  end
end
