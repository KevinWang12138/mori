import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import { Markdown } from '@tiptap/markdown'
import { TableKit } from '@tiptap/extension-table'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import Placeholder from '@tiptap/extension-placeholder'
import { lineNumbers, EditorView } from '@codemirror/view'
import { BlockMath, InlineMath, LocalImage, CodeBlock } from './extensions'
import { HeadingAnchors, FocusParagraph } from './editor-decorations'
import { splitFrontMatter, requiresSourceMode, safeLink, assetURL } from './document'
import { createSourceEditor, configureSourceLanguage } from './source-editor'
import { post, type DocumentPayload, type EditorSettings } from './bridge'
import { renderMarkdown, renderDiagrams } from './renderer'
import { formatRich, formatSource } from './formatting'
import { findInRich, insertItems } from './writing-tools'
import { readMetadata, updateMetadata } from './metadata'
import { editorLanguage, localize, setEditorLanguage, t } from './i18n'
import { focusDocument } from './editor-focus'
import { EditorSelectionUI } from './editor-selection'
import { ArticlePreview } from './article-preview'
import './style.css'
import 'katex/dist/katex.min.css'

const richHost = document.querySelector<HTMLElement>('#rich')!
const sourceHost = document.querySelector<HTMLElement>('#source')!
const preview = document.querySelector<HTMLElement>('#preview')!
const bubble = document.querySelector<HTMLElement>('#bubble')!
const slash = document.querySelector<HTMLElement>('#slash')!
const customStyle = document.createElement('style'); customStyle.id = 'custom-theme'; document.head.append(customStyle)
let active: DocumentEditor | undefined
let settings: EditorSettings | undefined
const documents = new Map<string, DocumentEditor>()
const selectionUI = new EditorSelectionUI({ active: () => active, typewriter: () => settings?.typewriterMode === true,
  richHost, sourceHost, bubble, slash })

class DocumentEditor {
  readonly id: string
  markdown: string
  directory: string
  mode: DocumentPayload['mode']
  readonly richMount = document.createElement('div')
  readonly sourceMount = document.createElement('div')
  readonly rich: Editor
  readonly source: ReturnType<typeof createSourceEditor>
  private suppress = false
  private richMarkdown: string
  private sourceLanguage = editorLanguage()
  private showLineNumbers = true
  readonly preview = new ArticlePreview(async content => {
    const staging = document.createElement('article'); staging.className = 'markdown-content'
    staging.innerHTML = renderMarkdown(content.markdown, content.directory)
    await renderDiagrams(staging, content.dark)
    return staging
  }, staging => {
    if (active !== this || this.mode !== 'split') return
    const scroll = preview.scrollTop; preview.replaceChildren(staging); preview.scrollTop = scroll
  }, () => post({ type: 'error' }))

  constructor(payload: DocumentPayload) {
    this.suppress = true
    this.id = payload.id; this.markdown = payload.markdown; this.richMarkdown = payload.markdown
    this.directory = payload.directory; this.mode = payload.mode
    this.richMount.className = 'rich-document markdown-content'; this.sourceMount.className = 'source-document'
    this.rich = new Editor({
      element: this.richMount,
      extensions: [StarterKit.configure({ codeBlock: false, link: { openOnClick: false, autolink: true } }),
        Markdown.configure({ markedOptions: { gfm: true, breaks: false }, indentation: { style: 'space', size: 2 } }),
        TableKit.configure({ table: { resizable: true } }), TaskList, TaskItem.configure({ nested: true }),
        LocalImage.configure({ directory: () => this.directory }), CodeBlock, InlineMath, BlockMath, HeadingAnchors, FocusParagraph, Placeholder.configure({ placeholder: () => t('把想法写下来，或输入 / 插入内容…') })],
      content: requiresSourceMode(payload.markdown) ? '' : splitFrontMatter(payload.markdown).body, contentType: 'markdown',
      editorProps: { attributes: { 'aria-label': t('文章所见即所得编辑器'), spellcheck: 'true' },
        handlePaste: (_view, event) => this.handleFiles(event.clipboardData?.files),
        handleDrop: (_view, event) => this.handleFiles(event.dataTransfer?.files)
      },
      onUpdate: ({ transaction }) => {
        if (this.suppress || this.mode !== 'rich') return
        this.markdown = splitFrontMatter(this.markdown).prefix + this.rich.getMarkdown() + '\n'
        this.richMarkdown = this.markdown
        post({ type: 'change', id: this.id, markdown: this.markdown })
        if (active === this) selectionUI.requestUpdate(!transaction.getMeta('pointer'))
      },
      onSelectionUpdate: ({ transaction }) => {
        if (active === this) selectionUI.requestUpdate(!transaction.getMeta('pointer'))
      }
    })
    this.source = createSourceEditor(this.sourceMount, payload.markdown, value => {
      if (this.suppress || this.mode === 'rich') return
      this.markdown = value; post({ type: 'change', id: this.id, markdown: value })
      if (this.mode === 'split') this.schedulePreview()
    }, (_view, followCaret) => {
      if (!this.suppress && active === this) selectionUI.requestUpdate(followCaret)
    })
    this.suppress = false
  }

  // ===== 外部内容替换只更新编辑器状态，不触发保存回写 =====
  replace(payload: DocumentPayload): void {
    if (this.directory !== payload.directory) {
      this.directory = payload.directory
      for (const image of this.rich.view.dom.querySelectorAll<HTMLImageElement>('img[data-mori-source]')) {
        image.src = assetURL(image.dataset.moriSource ?? '', this.directory)
      }
    }
    if (this.markdown === payload.markdown) return
    this.preview.cancel()
    this.suppress = true; this.markdown = payload.markdown
    this.source.view.dispatch({ changes: { from: 0, to: this.source.view.state.doc.length, insert: payload.markdown } })
    if (!requiresSourceMode(payload.markdown)) {
      this.rich.commands.setContent(splitFrontMatter(payload.markdown).body, { contentType: 'markdown', emitUpdate: false })
      this.richMarkdown = payload.markdown
    }
    this.suppress = false
  }

  setMode(mode: DocumentPayload['mode']): void {
    if (mode === 'rich' && requiresSourceMode(this.markdown)) { mode = 'source'; post({ type: 'unsupported' }) }
    const changed = this.mode !== mode
    this.mode = mode
    this.suppress = true
    if (mode === 'rich' && this.richMarkdown !== this.markdown) {
      this.rich.commands.setContent(splitFrontMatter(this.markdown).body, { contentType: 'markdown', emitUpdate: false }); this.richMarkdown = this.markdown
    } else if (mode !== 'rich' && this.source.view.state.doc.toString() !== this.markdown) {
      this.source.view.dispatch({ changes: { from: 0, to: this.source.view.state.doc.length, insert: this.markdown } })
    }
    this.suppress = false
    if (this.rich.isEditable !== (mode === 'rich')) this.rich.setEditable(mode === 'rich', false)
    if (this.source.view.state.facet(EditorView.editable) !== (mode !== 'rich')) {
      this.source.view.dispatch({ effects: this.source.editable.reconfigure(EditorView.editable.of(mode !== 'rich')) })
    }
    document.body.dataset.mode = mode
    if (mode === 'split') this.schedulePreview()
    else this.preview.cancel()
    selectionUI.dismiss()
    if (changed && active === this) document.querySelector('.find-panel')?.remove()
    requestAnimationFrame(() => {
      this.source.view.requestMeasure()
      if (changed && active === this) focusDocument(this.rich, this.source.view, mode, false)
    })
  }

  // ===== 只有语言或行号变化时才重配置源码编辑器，字体与主题调整不重建插件 =====
  configureSource(config: EditorSettings): void {
    const effects = this.showLineNumbers === config.showLineNumbers ? []
      : [this.source.numbers.reconfigure(config.showLineNumbers ? lineNumbers() : [])]
    if (this.sourceLanguage !== config.language) configureSourceLanguage(this.source.view, this.source.language, config.language, effects)
    else if (effects.length) this.source.view.dispatch({ effects })
    this.sourceLanguage = config.language; this.showLineNumbers = config.showLineNumbers
  }

  handleFiles(files?: FileList | null): boolean {
    if (!files?.length) return false
    const images = [...files].filter(file => file.type.startsWith('image/'))
    if (!images.length) return false
    for (const file of images) {
      if (file.size > 25 * 1024 * 1024) { post({ type: 'error' }); continue }
      const reader = new FileReader()
      reader.onload = () => post({ type: 'asset', id: this.id, name: file.name, data: String(reader.result).split(',')[1] })
      reader.readAsDataURL(file)
    }
    return true
  }

  schedulePreview(): void {
    this.preview.schedule({ markdown: this.markdown, directory: this.directory, dark: settings?.theme === 'night' })
  }

  syncPreviewScroll(): void {
    if (this.mode !== 'split') return
    const sourceScroll = this.source.view.scrollDOM
    const ratio = sourceScroll.scrollTop / Math.max(1, sourceScroll.scrollHeight - sourceScroll.clientHeight)
    preview.scrollTop = ratio * Math.max(0, preview.scrollHeight - preview.clientHeight)
  }

  dispose(): void { this.preview.cancel(); this.rich.destroy(); this.source.view.destroy() }
}

function configure(payload: Pick<DocumentPayload, 'mode' | 'settings'>): void {
  settings = payload.settings
  const css = document.documentElement.style
  const config = payload.settings
  const languageChanged = editorLanguage() !== config.language
  setEditorLanguage(config.language)
  if (languageChanged) {
    for (const entry of documents.values()) {
      entry.rich.setOptions({ editorProps: { ...entry.rich.options.editorProps,
        attributes: { 'aria-label': t('文章所见即所得编辑器'), spellcheck: String(config.spellcheck) } } })
      entry.rich.view.dispatch(entry.rich.state.tr.setMeta('mori-language-change', true))
      if (entry !== active) entry.configureSource(config)
    }
  }
  for (const [index, button] of [...slash.children].entries()) button.textContent = insertItems[index].symbol + '  ' + t(insertItems[index].label)
  document.documentElement.dataset.theme = config.theme
  css.setProperty('--text', config.text); css.setProperty('--muted', config.muted); css.setProperty('--accent', config.accent)
  css.setProperty('--surface', config.surface); css.setProperty('--font', config.font)
  css.setProperty('--font-size', `${config.fontSize}px`); css.setProperty('--line-height', String(config.lineHeight))
  css.setProperty('--page-width', `${config.pageWidth}px`)
  const color = config.surface.replace('#', '')
  css.setProperty('--paper', `rgba(${parseInt(color.slice(0, 2), 16)},${parseInt(color.slice(2, 4), 16)},${parseInt(color.slice(4, 6), 16)},${config.paperOpacity})`)
  document.body.classList.toggle('focus-mode', config.focusMode); document.body.classList.toggle('typewriter-mode', config.typewriterMode)
  customStyle.textContent = config.customCSS
  if (active) {
    active.rich.view.dom.setAttribute('spellcheck', String(config.spellcheck))
    active.configureSource(config)
    active.setMode(payload.mode); selectionUI.requestUpdate()
  }
}

function load(payload: DocumentPayload): void {
  let entry = documents.get(payload.id)
  const created = !entry
  if (!entry) { entry = new DocumentEditor(payload); documents.set(payload.id, entry) }
  else { entry.replace(payload) }
  const switched = active !== entry
  if (switched) { active?.preview.cancel(); preview.replaceChildren(); document.querySelector('.find-panel')?.remove() }
  active = entry
  if (richHost.firstChild !== entry.richMount) richHost.replaceChildren(entry.richMount)
  if (sourceHost.firstChild !== entry.sourceMount) sourceHost.replaceChildren(entry.sourceMount)
  configure(payload)
  if (switched) requestAnimationFrame(() => {
    if (active === entry) focusDocument(entry.rich, entry.source.view, entry.mode, created && payload.startsInBody === true)
  })
  if (!entry.sourceMount.dataset.events) {
    entry.sourceMount.dataset.events = 'true'
    entry.source.view.scrollDOM.addEventListener('scroll', () => entry?.syncPreviewScroll(), { passive: true })
    entry.source.view.contentDOM.addEventListener('paste', event => { if (entry?.handleFiles(event.clipboardData?.files)) event.preventDefault() })
    entry.source.view.contentDOM.addEventListener('drop', event => { if (entry?.handleFiles(event.dataTransfer?.files)) event.preventDefault() })
  }
}

function command(name: string, payload: Record<string, unknown> = {}): void {
  if (name === 'dispose') {
    selectionUI.dismiss()
    const id = String(payload.id)
    if (active?.id === id) { active = undefined; preview.replaceChildren() }
    documents.get(id)?.dispose(); documents.delete(id); return
  }
  if (!active) return
  if (name === 'find') {
    if (active.mode === 'rich') findInRich(active.rich)
    else formatSource(active.source.view, name, payload)
  } else if (name === 'jump') {
    if (active.mode === 'rich') {
      let index = 0; const desired = Number(payload.index)
      active.rich.state.doc.descendants((node, pos) => {
        if (node.type.name !== 'heading') return
        if (index++ === desired) active?.rich.commands.setTextSelection(pos + 1)
      })
      active.rich.commands.scrollIntoView(); active.rich.commands.focus()
    } else {
      const line = active.source.view.state.doc.line(Math.max(1, Math.min(Number(payload.line), active.source.view.state.doc.lines)))
      active.source.view.dispatch({ selection: { anchor: line.from }, scrollIntoView: true }); active.source.view.focus()
    }
  } else if (name === 'setMetadata') {
    const replacement = updateMetadata(active.markdown, payload)
    if (replacement === null) { post({ type: 'error' }); return }
    active.replace({ id: active.id, markdown: replacement, directory: active.directory, mode: active.mode, settings: settings! })
    post({ type: 'change', id: active.id, markdown: replacement }); if (active.mode === 'split') active.schedulePreview()
  } else {
    if (active.mode === 'rich') formatRich(active.rich, name, payload)
    else formatSource(active.source.view, name, payload)
  }
}

function toolButton(label: string, name: string, symbol: string): HTMLButtonElement {
  const button = document.createElement('button'); button.type = 'button'; localize(button, { title: label, aria: label })
  button.textContent = symbol; button.addEventListener('mousedown', event => event.preventDefault())
  button.onclick = () => command(name); return button
}

for (const [label, name, symbol] of [['加粗', 'bold', 'B'], ['斜体', 'italic', 'I'], ['删除线', 'strike', 'S'], ['行内代码', 'code', '</>'], ['链接', 'link', '↗']]) {
  bubble.append(toolButton(label, name, symbol))
}
for (const item of insertItems) {
  const button = toolButton(item.label, item.name, item.symbol + '  ' + t(item.label))
  button.onclick = () => {
    if (!active) return
    const { $from } = active.rich.state.selection
    active.rich.chain().deleteRange({ from: $from.start(), to: $from.pos }).run()
    command(item.name); slash.hidden = true
  }
  slash.append(button)
}
bubble.hidden = true; slash.hidden = true

document.addEventListener('click', event => {
  const anchor = (event.target as HTMLElement).closest<HTMLAnchorElement>('a[href]')
  if (!anchor) return
  event.preventDefault()
  const href = anchor.getAttribute('href') ?? ''
  if (href.startsWith('#')) {
    try { const id = decodeURIComponent(href.slice(1)); document.getElementById(id)?.scrollIntoView({ block: 'center' }) } catch { return }
  } else if (/^(https?:|mailto:)/i.test(href) && safeLink(href)) {
    if (active?.mode !== 'rich' || event.metaKey) post({ type: 'openURL', url: href })
  } else if (/\.(?:md|markdown)(?:#.*)?$/i.test(href)) { post({ type: 'openArticle', path: href }) }
})

document.addEventListener('keydown', event => {
  if (event.key === 'Escape') selectionUI.dismiss()
  if (event.key === 'ArrowDown' && !slash.hidden) { (slash.querySelector('button:not([hidden])') as HTMLButtonElement)?.focus(); event.preventDefault() }
})

window.Mori = {
  load, configure, command,
  metadata: documentID => { const entry = documents.get(documentID); return entry ? readMetadata(entry.markdown) : null },
  flush: () => ({ id: active?.id ?? '', markdown: active?.markdown ?? '' }),
  async exportHTML(documentID) {
    const entry = documents.get(documentID)
    if (!entry) return null
    const language = editorLanguage(); const fallbackTitle = t('文章')
    const rendered = document.createElement('article'); rendered.className = 'markdown-content'
    rendered.innerHTML = renderMarkdown(entry.markdown, entry.directory)
    await renderDiagrams(rendered, false)
    const styles = [...document.styleSheets].filter(sheet => sheet.ownerNode !== customStyle)
      .flatMap(sheet => { try { return [...sheet.cssRules].map(rule => rule.cssText) } catch { return [] } }).join('\n')
    const title = rendered.querySelector('h1')?.textContent ?? fallbackTitle
    const safeTitle = title.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    return `<!doctype html><html lang="${language}" data-theme="paper"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${safeTitle}</title><style>${styles}\n${exportStyles}</style></head><body>${rendered.outerHTML}</body></html>`
  }
}

const exportStyles = `:root{--text:#28362e;--muted:#778377;--accent:#3f654f;--surface:#fffefa;--paper:#fffefa;--font:'Iowan Old Style','Songti SC',serif;--font-size:18px;--line-height:1.85;--page-width:760px}html,body{height:auto!important;overflow:visible!important;background:#fffefa!important;color:#28362e!important}.markdown-content{max-width:760px;margin:0 auto;padding:50px 40px;box-shadow:none!important;border:none!important;min-height:0!important}pre,blockquote,table,img,.mermaid-output{break-inside:avoid}h1,h2,h3{break-after:avoid}@media print{.markdown-content{padding:0;max-width:none}@page{size:A4;margin:20mm}}`

window.addEventListener('error', () => post({ type: 'error' }))
post({ type: 'ready' })
