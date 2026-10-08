# frozen_string_literal: true

require 'test_helper'
require 'shellwords'
require 'fileutils'

class TurboNetworkErrorTest < ActiveSupport::TestCase
  test 'fetch request error shows bottom-right toast and restores form sidebar' do
    Dir.mktmpdir do |dir|
      FileUtils.cp(Rails.root.join('app/javascript/lib/toast.js'), File.join(dir, 'toast.mjs'))
      network_src = File.read(Rails.root.join('app/javascript/turbo/network_error.js'))
                        .sub("from 'lib/toast'", "from './toast.mjs'")
      File.write(File.join(dir, 'network_error.mjs'), network_src)
      check = File.join(dir, 'check.mjs')
      File.write(check, <<~JS)
        import {
          handleTurboFetchRequestError,
          networkErrorMessage,
          showNetworkAlert
        } from './network_error.mjs'

        const assert = (cond, msg) => { if (!cond) { console.error(msg); process.exit(1) } }

        globalThis.CustomEvent = class CustomEvent {
          constructor (type, init = {}) { this.type = type; this.bubbles = !!init.bubbles }
        }

        function el (tag, attrs = {}, kids = []) {
          const node = {
            localName: tag.toLowerCase(),
            tagName: tag.toUpperCase(),
            attributes: { ...attrs },
            children: [],
            parent: null,
            textContent: '',
            className: '',
            style: {},
            getAttribute (name) { return this.attributes[name] ?? null },
            setAttribute (name, value) { this.attributes[name] = String(value) },
            removeAttribute (name) { delete this.attributes[name] },
            hasAttribute (name) { return Object.prototype.hasOwnProperty.call(this.attributes, name) },
            appendChild (child) { child.parent = this; this.children.push(child); return child },
            prepend (...nodes) {
              nodes.reverse().forEach((n) => { n.parent = this; this.children.unshift(n) })
            },
            replaceChildren (...nodes) {
              this.children = []
              nodes.forEach((n) => this.appendChild(n))
            },
            querySelector (sel) {
              if (sel.startsWith('#')) {
                const id = sel.slice(1)
                const walk = (n) => {
                  if (n.attributes?.id === id || n.id === id) return n
                  for (const c of n.children || []) {
                    const hit = walk(c)
                    if (hit) return hit
                  }
                  return null
                }
                return walk(this)
              }
              if (sel.startsWith('meta[')) {
                return this.children.find((c) => c.localName === 'meta') || null
              }
              if (sel === '[data-v2-toast-stack]') {
                return this._toastStack || null
              }
              return null
            },
            querySelectorAll (sel) {
              const out = []
              const walk = (n) => {
                if (sel === 'turbo-frame[busy]' && n.localName === 'turbo-frame' && n.hasAttribute('busy')) out.push(n)
                if (sel === '[data-v2-toast]' && n.attributes && 'data-v2-toast' in n.attributes) out.push(n)
                for (const c of n.children || []) walk(c)
              }
              walk(this)
              if (sel === '[data-v2-toast]' && this._toastStack) {
                this._toastStack.children.forEach((c) => {
                  if (c.attributes && 'data-v2-toast' in c.attributes) out.push(c)
                })
              }
              return out
            },
            closest (sel) {
              if (sel === 'turbo-frame' && this.localName === 'turbo-frame') return this
              let p = this.parent
              while (p) {
                if (sel === 'turbo-frame' && p.localName === 'turbo-frame') return p
                p = p.parent
              }
              return null
            },
            dispatchEvent () { return true },
            remove () {
              if (!this.parent) return
              this.parent.children = this.parent.children.filter((c) => c !== this)
            },
            addEventListener () {}
          }
          Object.keys(attrs).forEach((k) => {
            node.setAttribute(k, attrs[k])
            if (k === 'class') node.className = attrs[k]
            if (k === 'id') node.id = attrs[k]
          })
          kids.forEach((k) => node.appendChild(k))
          return node
        }

        const meta = el('meta', { name: 'turbo-network-error-message', content: 'Le serveur n’est pas disponible. Veuillez réessayer.' })
        const tplContent = el('template-content')
        tplContent.cloneNode = () => el('p', { class: 'form-sidebar-placeholder' })
        const tpl = el('template', { id: 'form-sidebar-placeholder-template' })
        tpl.content = tplContent

        const frame = el('turbo-frame', { id: 'form_sidebar', src: '/destinations/1/edit', busy: '' })
        frame.id = 'form_sidebar'
        frame.setAttribute('aria-busy', 'true')
        frame.appendChild(el('div'))

        const body = el('body')
        const doc = el('document')
        doc.documentElement = el('html')
        doc.documentElement.setAttribute('aria-busy', 'true')
        doc.body = body
        doc.appendChild(meta)
        doc.appendChild(tpl)
        doc.appendChild(frame)
        doc.createElement = (tag) => el(tag)
        doc.getElementById = (id) => (tpl.attributes.id === id ? tpl : doc.querySelector('#' + id))
        // toastStack appends to body — keep a searchable stack reference on doc.
        const origAppend = body.appendChild.bind(body)
        body.appendChild = (child) => {
          if (child.attributes && 'data-v2-toast-stack' in child.attributes) doc._toastStack = child
          return origAppend(child)
        }

        assert(networkErrorMessage(doc).includes('serveur'), 'reads meta message')

        handleTurboFetchRequestError({ target: frame }, doc)

        assert(!frame.hasAttribute('src'), 'clears form_sidebar src')
        assert(!frame.hasAttribute('busy'), 'clears busy')
        assert(frame.children[0].className.includes('form-sidebar-placeholder'), 'placeholder restored')

        const stack = doc._toastStack
        assert(stack && stack.className.includes('v2-toast-stack'), 'toast stack created')
        const toast = stack.children[0]
        assert(toast && toast.getAttribute('data-v2-toast') === '', 'toast item')
        assert(toast.className.includes('alert-danger'), 'danger class')
        assert(toast.className.includes('v2-toast'), 'toast class')
        assert(toast.children[0].textContent.includes('serveur'), 'toast message')

        showNetworkAlert('retry', doc)
        assert(stack.children.length === 2, 'second sticky toast stacks')

        console.log('ok')
      JS
      out = `node #{Shellwords.escape(check)}`
      assert_match(/ok/, out)
    end
  end
end
