import { test, before } from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import type { Editor as TiptapEditor } from '@tiptap/core'

let createEditor: (markdown: string) => TiptapEditor
before(async () => {
  const dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'https://local.invalid' })
  for (const key of ['window', 'document', 'navigator', 'Node', 'HTMLElement', 'Element', 'MutationObserver', 'DOMParser', 'getComputedStyle', 'CustomEvent']) {
    Object.defineProperty(globalThis, key, { value: Reflect.get(dom.window, key), configurable: true })
  }
  Object.defineProperty(globalThis, 'requestAnimationFrame', { value: (callback: FrameRequestCallback) => setTimeout(callback, 0), configurable: true })
  Object.defineProperty(globalThis, 'cancelAnimationFrame', { value: (id: ReturnType<typeof setTimeout>) => clearTimeout(id), configurable: true })
  const [{ Editor }, { default: StarterKit }, { Markdown }, { TableKit }, { default: TaskList }, { default: TaskItem }, { default: Image }] = await Promise.all([
    import('@tiptap/core'), import('@tiptap/starter-kit'), import('@tiptap/markdown'), import('@tiptap/extension-table'),
    import('@tiptap/extension-task-list'), import('@tiptap/extension-task-item'), import('@tiptap/extension-image')
  ])
  const { InlineMath, BlockMath, CodeBlock } = await import('../src/extensions')
  createEditor = markdown => new Editor({ element: document.createElement('div'), extensions: [StarterKit.configure({ codeBlock: false }), Markdown, TableKit, TaskList, TaskItem.configure({ nested: true }), Image, InlineMath, BlockMath, CodeBlock], content: markdown, contentType: 'markdown' })
})

test('标题、内联格式、嵌套任务、表格、代码与图片可往返', () => {
  const source = '# Hello\n\n**Bold** and *italic* and ~~strike~~ and `code`.\n\n- [x] done\n- [ ] todo\n\n| Name | Value |\n| --- | --- |\n| One | Two |\n\n```swift\nlet text = "你好"\n```\n\n![描述](assets/中文.png)\n'
  const editor = createEditor(source)
  const markdown = editor.getMarkdown()
  assert.ok(markdown.includes('# Hello'))
  assert.ok(markdown.includes('**Bold**'))
  assert.ok(markdown.includes('- [x] done'))
  assert.ok(markdown.includes('- [ ] todo'))
  assert.ok(markdown.includes('| Name | Value |'))
  assert.ok(markdown.includes('```swift'))
  assert.ok(markdown.includes('let text = "你好"'))
  assert.ok(markdown.includes('![描述](assets/中文.png)'))
  const second = createEditor(markdown)
  assert.deepEqual(second.getJSON(), editor.getJSON())
  second.destroy(); editor.destroy()
})

test('插入表格、行列操作和撤销真实有效', () => {
  const editor = createEditor('# Article\n\nText')
  editor.commands.setTextSelection(editor.state.doc.content.size - 1)
  assert.ok(editor.commands.insertTable({ rows: 3, cols: 2, withHeaderRow: true }))
  assert.ok(editor.getMarkdown().includes('|'))
  assert.ok(editor.commands.addRowAfter())
  const afterRows = editor.getMarkdown()
  assert.ok(editor.commands.addColumnAfter())
  assert.notEqual(editor.getMarkdown(), afterRows)
  assert.ok(editor.commands.undo())
  editor.destroy()
})

test('公式扩展解析内联与块级公式，编辑后保留 Markdown 语义', () => {
  const editor = createEditor('# Math\n\nInline $a^2$ here.\n\n$$\nE = mc^2\n$$\n')
  const json = JSON.stringify(editor.getJSON())
  assert.ok(json.includes('inlineMath'))
  assert.ok(json.includes('blockMath'))
  assert.ok(editor.getMarkdown().includes('$a^2$'))
  assert.ok(editor.getMarkdown().includes('$$\nE = mc^2\n$$'))
  editor.destroy()
})

test('代码块保留语言与正文，Mermaid 源码不会被渲染结果替换', () => {
  const editor = createEditor('```mermaid\nflowchart LR\n  A --> B\n```\n\n```js\nconst x = 1\n```\n')
  const markdown = editor.getMarkdown()
  assert.ok(markdown.includes('```mermaid\nflowchart LR\n  A --> B'))
  assert.ok(markdown.includes('```js\nconst x = 1'))
  editor.destroy()
})

test('富文本查找跨加粗边界且替换可撤销', async () => {
  const { findMatches } = await import('../src/writing-tools')
  const editor = createEditor('Hello **world**. Hello world.')
  const matches = findMatches(editor.state.doc, 'hello world')
  assert.equal(matches.length, 2)
  assert.equal(findMatches(editor.state.doc, 'hello world', true).length, 0)
  const transaction = editor.state.tr
  for (const match of [...matches].reverse()) transaction.insertText('你好', match.from, match.to)
  editor.view.dispatch(transaction)
  assert.equal(editor.state.doc.textContent, '你好. 你好.')
  assert.ok(editor.commands.undo())
  assert.equal(editor.state.doc.textContent, 'Hello world. Hello world.')
  editor.destroy()
})

test('所见即所得语言切换保留文章、选区与撤销，代码工具即时翻译', async () => {
  const { setEditorLanguage } = await import('../src/i18n')
  setEditorLanguage('en')
  const editor = createEditor('# 中文标题\n\nKeep my words.\n\n```swift\nlet title = "你好"\n```')
  document.body.append(editor.view.dom)
  editor.commands.setTextSelection(2)
  editor.commands.insertContent('Edited ')
  const markdown = editor.getMarkdown(); const selection = editor.state.selection.toJSON()
  const input = editor.view.dom.querySelector<HTMLInputElement>('.code-toolbar input')!
  assert.equal(input.placeholder, 'Code language')
  setEditorLanguage('zh-CN')
  editor.view.dispatch(editor.state.tr.setMeta('mori-language-change', true))
  assert.equal(input.placeholder, '代码语言'); assert.equal(editor.getMarkdown(), markdown)
  assert.deepEqual(editor.state.selection.toJSON(), selection)
  setEditorLanguage('en')
  editor.view.dispatch(editor.state.tr.setMeta('mori-language-change', true))
  assert.equal(input.placeholder, 'Code language'); assert.equal(input.value, 'swift')
  assert.ok(editor.commands.undo()); assert.ok(editor.getMarkdown().startsWith('# 中文标题'))
  editor.destroy()
})
