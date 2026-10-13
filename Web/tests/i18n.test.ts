import { before, test } from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { EditorState, Compartment } from '@codemirror/state'
import { history, undoDepth, undo } from '@codemirror/commands'
import { openSearchPanel } from '@codemirror/search'
import { localize, setEditorLanguage, t } from '../src/i18n'
import { createSourceEditor, configureSourceLanguage, sourceLanguageExtension } from '../src/source-editor'
import english from '../../Sources/Mori/Resources/Localization/en.json'
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { join } from 'node:path'

before(() => {
  const dom = new JSDOM('<!doctype html><html><body></body></html>', { pretendToBeVisual: true })
  for (const key of ['window', 'Window', 'document', 'CustomEvent', 'HTMLElement', 'Node', 'Element', 'MutationObserver', 'navigator', 'getComputedStyle']) {
    Object.defineProperty(globalThis, key, { value: Reflect.get(dom.window, key), configurable: true })
  }
  Object.defineProperty(globalThis, 'requestAnimationFrame', { value: (callback: FrameRequestCallback) => setTimeout(callback, 0), configurable: true })
  Object.defineProperty(globalThis, 'cancelAnimationFrame', { value: (id: ReturnType<typeof setTimeout>) => clearTimeout(id), configurable: true })
})

test('已打开的工具与对话框立即切换，保留用户输入', () => {
  setEditorLanguage('en')
  const input = document.createElement('input'); input.value = '用户的文字 stays unchanged'
  localize(input, { placeholder: '查找内容', aria: '查找内容' })
  const button = document.createElement('button'); localize(button, { text: '全部替换', title: '全部替换' })
  document.body.replaceChildren(input, button)
  assert.equal(input.placeholder, 'Find text'); assert.equal(button.textContent, 'Replace all')
  setEditorLanguage('zh-CN')
  assert.equal(document.documentElement.lang, 'zh-CN'); assert.equal(input.placeholder, '查找内容')
  assert.equal(button.textContent, '全部替换'); assert.equal(input.value, '用户的文字 stays unchanged')
  setEditorLanguage('en')
  assert.equal(button.textContent, 'Replace all'); assert.equal(input.value, '用户的文字 stays unchanged')
})

test('源码查找语言切换保留原稿、光标与撤销记录', () => {
  const language = new Compartment()
  let state = EditorState.create({ doc: '# 你好\n\nUntouched YAML: title: 中文', extensions: [history(), language.of(sourceLanguageExtension('en'))] })
  state = state.update({ changes: { from: state.doc.length, insert: '\nEdited' }, selection: { anchor: 3 } }).state
  const source = state.doc.toString(); const cursor = state.selection.main.anchor
  const depth = undoDepth(state)
  state = state.update({ effects: language.reconfigure(sourceLanguageExtension('zh-CN')) }).state
  assert.equal(state.phrase('Find'), '查找'); assert.equal(state.doc.toString(), source)
  assert.equal(state.selection.main.anchor, cursor); assert.equal(undoDepth(state), depth)
  state = state.update({ effects: language.reconfigure(sourceLanguageExtension('en')) }).state
  assert.equal(state.phrase('Find'), 'Find'); assert.equal(state.doc.toString(), source)
  assert.ok(undo({ state, dispatch: transaction => { state = transaction.state } }))
  assert.equal(state.doc.toString(), '# 你好\n\nUntouched YAML: title: 中文')
})

test('已打开的源码查找面板翻译时保留输入、正则选项和原文', () => {
  setEditorLanguage('en')
  const parent = document.createElement('div'); document.body.append(parent)
  const source = createSourceEditor(parent, '# 中文标题\n\nMy words.', () => {}, () => {})
  try {
    openSearchPanel(source.view)
    const input = parent.querySelector<HTMLInputElement>('input[name="search"]')!
    const checkbox = parent.querySelector<HTMLInputElement>('input[name="re"]')!
    input.value = 'My.*words'; checkbox.checked = true
    configureSourceLanguage(source.view, source.language, 'zh-CN')
    const translatedInput = parent.querySelector<HTMLInputElement>('input[name="search"]')!
    assert.equal(translatedInput.placeholder, '查找'); assert.equal(translatedInput.value, 'My.*words')
    assert.equal(source.view.contentDOM.getAttribute('aria-label'), 'Markdown 源码编辑器')
    assert.ok(parent.querySelector<HTMLInputElement>('input[name="re"]')!.checked)
    assert.equal(parent.querySelector('button[name="replaceAll"]')?.textContent, '全部替换')
    assert.equal(source.view.state.doc.toString(), '# 中文标题\n\nMy words.')
  } finally { source.view.destroy(); parent.remove() }
})

test('共用中英文文案表覆盖原生界面与编辑器文案，格式占位一致', () => {
  const catalog: Record<string, string> = english
  for (const [key, value] of Object.entries(catalog)) {
    assert.ok(value.trim(), key)
    assert.deepEqual(value.match(/%[d@]/g) ?? [], key.match(/%[d@]/g) ?? [], key)
  }
  const native = fileURLToPath(new URL('../../Sources/Mori', import.meta.url))
  const scan = (directory: string): void => {
    for (const item of readdirSync(directory, { withFileTypes: true })) {
      const path = join(directory, item.name)
      if (item.isDirectory() && item.name !== 'Resources') scan(path)
      else if (item.name.endsWith('.swift')) {
        const source = readFileSync(path, 'utf8')
        for (const match of source.matchAll(/L10n\.(?:text|format)\("((?:\\.|[^"\\])*)"/g)) {
          const key: string = JSON.parse('"' + match[1] + '"')
          assert.ok(key in catalog, `${item.name}: ${key}`)
        }
      }
    }
  }
  scan(native)
  const core = readFileSync(new URL('../../Sources/MoriCore/DocumentFileService.swift', import.meta.url), 'utf8')
  for (const match of core.matchAll(/return "([^"\n]*[\u4e00-\u9fff][^"\n]*)"/g)) assert.ok(match[1] in catalog, match[1])
  setEditorLanguage('en'); assert.equal(t('图片信息'), 'Image details')
  setEditorLanguage('zh-CN'); assert.equal(t('图片信息'), '图片信息')
})
