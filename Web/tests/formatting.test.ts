import { before, test } from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import type { createSourceEditor } from '../src/source-editor'
import type { formatSource } from '../src/formatting'

let createSource: typeof createSourceEditor
let format: typeof formatSource
let render: typeof import('../src/renderer').renderMarkdown

before(async () => {
  const dom = new JSDOM('<!doctype html><html><body></body></html>', { pretendToBeVisual: true })
  for (const key of ['window', 'Window', 'document', 'navigator', 'Node', 'HTMLElement', 'Element', 'MutationObserver', 'DOMParser', 'getComputedStyle']) {
    Object.defineProperty(globalThis, key, { value: Reflect.get(dom.window, key), configurable: true })
  }
  createSource = (await import('../src/source-editor')).createSourceEditor
  format = (await import('../src/formatting')).formatSource
  render = (await import('../src/renderer')).renderMarkdown
})

// ===== 使用真实源码编辑器验证命令只改动已选中的行 =====
function apply(content: string, command: string, anchor: number, head = anchor, payload: Record<string, unknown> = {}): string {
  const parent = document.createElement('div'); document.body.append(parent)
  const { view } = createSource(parent, content, () => {}, () => {})
  try {
    view.dispatch({ selection: { anchor, head } })
    format(view, command, payload)
    return view.state.doc.toString()
  } finally { view.destroy(); parent.remove() }
}

test('任务列表转普通段落、列表或标题不会遗留复选框标记', () => {
  assert.equal(apply('- [x] 完成', 'paragraph', 5), '完成')
  assert.equal(apply('- [ ] 待办', 'bullet', 5), '- 待办')
  assert.equal(apply('* [X] 完成', 'heading2', 5), '## 完成')
  assert.equal(apply('- [ ] 待办', 'task', 5), '- [ ] 待办')
})

test('选区恰好停在下一行开头时不格式化未选择的下一行', () => {
  assert.equal(apply('第一行\n第二行\n第三行', 'bullet', 0, 4), '- 第一行\n第二行\n第三行')
  assert.equal(apply('第一行\n第二行\n第三行', 'quote', 8, 0), '> 第一行\n> 第二行\n第三行')
  assert.equal(apply('第一行\n第二行', 'heading1', 4), '第一行\n# 第二行')
})

test('插入图片时文件名中的括号和反斜线不会破坏 Markdown', () => {
  const alt = '图片 [草稿] \\ 预览'
  const markdown = apply('', 'insertImage', 0, 0, { alt, src: 'assets/preview (1).png' })
  const html = render(markdown, '/blog')
  const image = new DOMParser().parseFromString(html, 'text/html').querySelector('img')
  assert.equal(image?.getAttribute('alt'), alt)
  assert.equal(image?.getAttribute('src'), 'mori-asset://local/blog/assets/preview%20(1).png')
})
