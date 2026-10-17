import { before, after, test } from 'node:test'
import assert from 'node:assert/strict'
import { build } from 'esbuild'
import { JSDOM } from 'jsdom'
import { EditorView } from '@codemirror/view'
import type { DocumentPayload, EditorSettings, NativeMessage } from '../src/bridge'

let dom: JSDOM
let editor: Window['Mori']
const messages: NativeMessage[] = []
const settings: EditorSettings = {
  language: 'zh-CN', theme: 'paper', surface: '#fffefa', text: '#28362e', muted: '#778377', accent: '#3f654f',
  font: 'serif', fontSize: 18, lineHeight: 1.85, pageWidth: 760, paperOpacity: 1, spellcheck: true,
  showLineNumbers: true, focusMode: false, typewriterMode: false, customCSS: ''
}

before(async () => {
  const bundle = await build({ entryPoints: ['src/main.ts'], bundle: true, write: false, format: 'iife', loader: { '.css': 'empty' } })
  dom = new JSDOM('<!doctype html><html><body><main id="rich"></main><main id="source"></main><main id="preview"></main><div id="bubble"></div><div id="slash"></div></body></html>',
    { url: 'https://local.invalid', pretendToBeVisual: true, runScripts: 'outside-only' })
  Object.defineProperty(dom.window, 'webkit', { value: { messageHandlers: { mori: { postMessage: (message: NativeMessage) => messages.push(message) } } } })
  dom.window.eval(bundle.outputFiles[0].text)
  editor = dom.window.Mori
})

after(() => { dom.window.close() })

function article(id: string, markdown: string, mode: DocumentPayload['mode'] = 'rich', directory = '/' + id): DocumentPayload {
  return { id, markdown, directory, mode, settings: { ...settings } }
}

test('每份文章的本地图片在首次加载和切回时使用自己的目录', () => {
  const first = article('images-a', '![第一张](assets/first.png)')
  const second = article('images-b', '![第二张](assets/second.png)')
  editor.load(first)
  assert.equal(dom.window.document.querySelector('#rich img')?.getAttribute('src'), 'mori-asset://local/images-a/assets/first.png')
  editor.load(second)
  assert.equal(dom.window.document.querySelector('#rich img')?.getAttribute('src'), 'mori-asset://local/images-b/assets/second.png')
  editor.load(first)
  assert.equal(dom.window.document.querySelector('#rich img')?.getAttribute('src'), 'mori-asset://local/images-a/assets/first.png')
  editor.command('dispose', { id: first.id }); editor.command('dispose', { id: second.id })
})

test('文章另存目录后保留内容、撤销记录，图片路径立即更新且不回写正文', () => {
  const original = article('move', '# 原始标题\n\n![图片](pic.png)')
  editor.load(original); editor.command('insertText', { text: '新增内容' })
  const edited = editor.flush().markdown
  const count = messages.filter(message => message.type === 'change').length
  editor.load({ ...original, markdown: edited, directory: '/moved' })
  assert.equal(editor.flush().markdown, edited)
  assert.equal(dom.window.document.querySelector('#rich img')?.getAttribute('src'), 'mori-asset://local/moved/pic.png')
  assert.equal(messages.filter(message => message.type === 'change').length, count)
  editor.command('undo')
  assert.ok(!editor.flush().markdown.includes('新增内容'))
  assert.ok(editor.flush().markdown.includes('原始标题'))
  editor.command('dispose', { id: original.id })
})

test('调整外观不重配源码状态，语言与行号变化仍生效', () => {
  const payload = article('config', '# 标题\n\n正文', 'source')
  editor.load(payload)
  const view = EditorView.findFromDOM(dom.window.document.querySelector('#source .cm-editor')!)!
  const state = view.state
  editor.configure({ mode: 'source', settings: { ...settings, fontSize: 22 } })
  assert.equal(view.state, state)
  editor.configure({ mode: 'source', settings: { ...settings, language: 'en', showLineNumbers: false } })
  assert.notEqual(view.state, state)
  assert.equal(view.contentDOM.getAttribute('aria-label'), 'Markdown source editor')
  assert.equal(dom.window.document.querySelector('#source .cm-lineNumbers'), null)
  assert.equal(editor.flush().markdown, payload.markdown)
  editor.command('dispose', { id: payload.id })
})

test('导出和元信息读取固定文章 ID，异步期间切换标签与语言不串稿', async () => {
  const first = article('export-a', '---\ntitle: 第一篇\n---\n# 第一篇\n\n![图片](pic.png)')
  const second = article('export-b', '---\ntitle: 第二篇\n---\n# 第二篇')
  editor.load(first); editor.load(second)
  const exported = editor.exportHTML(first.id)
  editor.configure({ mode: 'rich', settings: { ...settings, language: 'en' } })
  const html = await exported
  assert.ok(html?.includes('第一篇')); assert.ok(!html?.includes('第二篇'))
  assert.ok(html?.includes('mori-asset://local/export-a/pic.png'))
  assert.ok(html?.includes('lang="zh-CN"'))
  assert.equal(editor.metadata(first.id)?.title, '第一篇')
  assert.equal(editor.metadata(second.id)?.title, '第二篇')
  editor.command('dispose', { id: second.id })
  assert.equal(editor.flush().id, '')
  assert.equal(await editor.exportHTML(second.id), null)
  assert.equal(editor.metadata(second.id), null)
  editor.command('dispose', { id: first.id })
})
