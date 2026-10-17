import { Node, InputRule, mergeAttributes } from '@tiptap/core'
import { Plugin } from '@tiptap/pm/state'
import Image from '@tiptap/extension-image'
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import { common, createLowlight } from 'lowlight'
import katex from 'katex'
import { assetURL } from './document'
import { editFields } from './dialogs'
import { renderDiagram } from './renderer'
import { localize } from './i18n'

let getDirectory = () => ''
export function configureAssetDirectory(getter: () => string): void { getDirectory = getter }

export const LocalImage = Image.extend({
  addNodeView() {
    return ({ node, getPos, editor }) => {
      let current = node
      const image = document.createElement('img')
      const update = () => {
        image.src = assetURL(String(current.attrs.src ?? ''), getDirectory())
        image.alt = String(current.attrs.alt ?? ''); image.title = String(current.attrs.title ?? '')
      }
      update()
      image.addEventListener('dblclick', () => {
        editFields('图片信息', [{ label: '图片路径或 HTTPS 地址', value: String(current.attrs.src) }, { label: '图片描述', value: String(current.attrs.alt ?? '') }], values => {
          const pos = getPos(); if (typeof pos !== 'number') return
          editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { ...current.attrs, src: values[0], alt: values[1] }))
        })
      })
      return { dom: image, update(next) { if (next.type !== current.type) return false; current = next; update(); return true } }
    }
  }
}).configure({ allowBase64: true })

export const CodeBlock = CodeBlockLowlight.extend({
  // ===== 代码高亮只处理内容事务，选区变化复用现有装饰以免全文扫描 =====
  addProseMirrorPlugins() {
    return (this.parent?.() ?? []).map((plugin: Plugin<unknown>) => {
      const state = plugin.spec.state
      if (!state || !plugin.spec.props?.decorations) return plugin
      return new Plugin<unknown>({ ...plugin.spec, state: { ...state,
        apply: (transaction, previous, oldState, newState) => transaction.docChanged
          ? state.apply(transaction, previous, oldState, newState) : previous
      } })
    })
  },
  addNodeView() {
    return ({ node, getPos, editor }) => {
      let current = node
      const wrapper = document.createElement('div'); wrapper.className = 'code-block'
      const toolbar = document.createElement('div'); toolbar.className = 'code-toolbar'; toolbar.contentEditable = 'false'
      const language = document.createElement('input'); language.value = String(node.attrs.language ?? '')
      localize(language, { placeholder: '代码语言', aria: '代码语言' }); language.spellcheck = false
      const hint = document.createElement('span'); localize(hint, { text: '⌘↩ 继续写作' })
      toolbar.append(language, hint)
      const pre = document.createElement('pre'); const code = document.createElement('code'); pre.append(code)
      const diagram = document.createElement('div'); diagram.className = 'diagram-live'; diagram.contentEditable = 'false'
      wrapper.append(toolbar, pre, diagram)
      let timer: ReturnType<typeof setTimeout> | undefined
      const updateDiagram = () => {
        const isDiagram = current.attrs.language === 'mermaid'; diagram.hidden = !isDiagram
        if (timer) clearTimeout(timer)
        if (isDiagram) timer = setTimeout(() => { void renderDiagram(current.textContent, diagram) }, 350)
      }
      language.addEventListener('change', () => {
        const pos = getPos(); if (typeof pos !== 'number') return
        editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { ...current.attrs, language: language.value.trim() || null }))
      })
      updateDiagram()
      return {
        dom: wrapper, contentDOM: code,
        update(next) {
          if (next.type !== current.type) return false
          const changed = !next.eq(current)
          current = next; if (document.activeElement !== language) language.value = String(next.attrs.language ?? '')
          if (changed) updateDiagram()
          return true
        },
        stopEvent: event => toolbar.contains(event.target as globalThis.Node),
        destroy() { if (timer) clearTimeout(timer) }
      }
    }
  }
}).configure({ lowlight: createLowlight(common), enableTabIndentation: true })

function mathExtension(block: boolean) {
  const name = block ? 'blockMath' : 'inlineMath'
  const pattern = block ? /^\$\$[ \t]*\n?([\s\S]*?)\n?\$\$(?:\n|$)/ : /^\$([^$\n]+)\$/
  return Node.create({
    name, group: block ? 'block' : 'inline', inline: !block, atom: true,
    addAttributes() { return { latex: { default: '' } } },
    parseHTML() { return [{ tag: `${block ? 'div' : 'span'}[data-math]` }] },
    renderHTML({ HTMLAttributes }) { return [block ? 'div' : 'span', mergeAttributes(HTMLAttributes, { 'data-math': name })] },
    markdownTokenizer: {
      name, level: block ? 'block' : 'inline',
      start: (src: string) => src.indexOf(block ? '$$' : '$'),
      tokenize(src: string) {
        const match = pattern.exec(src)
        return match ? { type: name, raw: match[0], latex: match[1] } : undefined
      }
    },
    parseMarkdown(token, helpers) { return helpers.createNode(name, { latex: String(token.latex ?? '') }) },
    renderMarkdown(node) { return block ? `$$\n${node.attrs?.latex ?? ''}\n$$` : `$${node.attrs?.latex ?? ''}$` },
    addInputRules() {
      if (block) return []
      return [new InputRule({ find: /\$([^$\n]+)\$$/, handler: ({ state, range, match }) => {
        state.tr.replaceWith(range.from, range.to, this.type.create({ latex: match[1] }))
      } })]
    },
    addNodeView() {
      return ({ node, getPos, editor }) => {
        let current = node
        const dom = document.createElement(block ? 'div' : 'span'); dom.className = block ? 'math-block' : 'math-inline'
        const paint = () => { katex.render(String(current.attrs.latex), dom, { displayMode: block, throwOnError: false, trust: false, strict: 'ignore' }) }
        paint()
        dom.addEventListener('dblclick', () => {
          editFields('编辑公式', [{ label: 'LaTeX', value: String(current.attrs.latex), multiline: block }], values => {
            const pos = getPos(); if (typeof pos !== 'number') return
            editor.view.dispatch(editor.state.tr.setNodeMarkup(pos, undefined, { latex: values[0] }))
          })
        })
        return { dom, update(next) { if (next.type !== current.type) return false; current = next; paint(); return true } }
      }
    }
  })
}

export const InlineMath = mathExtension(false)
export const BlockMath = mathExtension(true)
