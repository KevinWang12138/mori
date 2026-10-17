import { test, before } from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import type { Editor } from '@tiptap/core'
import type { EditorSelectionUI } from '../src/editor-selection'
import type { createSourceEditor } from '../src/source-editor'

let createEditor: (element: HTMLElement, markdown: string, update: (follow: boolean) => void) => Editor
let createSource: typeof createSourceEditor
let SelectionUI: typeof EditorSelectionUI
let nextFrame = 0
const frames = new Map<number, FrameRequestCallback>()

before(async () => {
  const dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'https://local.invalid', pretendToBeVisual: true })
  for (const key of ['window', 'Window', 'document', 'navigator', 'Node', 'HTMLElement', 'Element', 'MutationObserver', 'DOMParser', 'getComputedStyle', 'CustomEvent']) {
    Object.defineProperty(globalThis, key, { value: Reflect.get(dom.window, key), configurable: true })
  }
  Object.defineProperty(globalThis, 'requestAnimationFrame', { value: (callback: FrameRequestCallback) => {
    const id = ++nextFrame; frames.set(id, callback); return id
  }, configurable: true })
  Object.defineProperty(globalThis, 'cancelAnimationFrame', { value: (id: number) => frames.delete(id), configurable: true })
  const [{ Editor }, { default: StarterKit }, { Markdown }, { default: Placeholder }, { CodeBlock }, { HeadingAnchors, FocusParagraph }] = await Promise.all([
    import('@tiptap/core'), import('@tiptap/starter-kit'), import('@tiptap/markdown'), import('@tiptap/extension-placeholder'),
    import('../src/extensions'), import('../src/editor-decorations')
  ])
  createEditor = (element, markdown, update) => new Editor({ element,
    extensions: [StarterKit.configure({ codeBlock: false }), Markdown, CodeBlock, HeadingAnchors, FocusParagraph, Placeholder],
    content: markdown, contentType: 'markdown',
    editorProps: { handleScrollToSelection: () => true },
    onSelectionUpdate: ({ transaction }) => update(!transaction.getMeta('pointer')),
    onUpdate: ({ transaction }) => update(!transaction.getMeta('pointer'))
  })
  createSource = (await import('../src/source-editor')).createSourceEditor
  SelectionUI = (await import('../src/editor-selection')).EditorSelectionUI
})

// ===== 手动执行已合并的选区帧，不启动浏览器或本地服务 =====
function flushFrames(): void {
  const pending = [...frames.entries()]
  for (const [id, callback] of pending) { frames.delete(id); callback(0) }
}

// ===== 在 DOM 测试环境中模拟指针生命周期 =====
function pointer(target: EventTarget, type: string, buttons = 1): void {
  const event = new window.MouseEvent(type, { bubbles: true, button: 0, buttons })
  Object.defineProperty(event, 'pointerId', { value: 1 })
  target.dispatchEvent(event)
}

// ===== 使用真实编辑器和受控布局读数验证拖选副作用 =====
function fixture(markdown = '# 标题\n\n第一段 **加粗文字** 与复制。\n\n第二段 English text.\n\n第三段结束。') {
  const root = document.createElement('section')
  const richHost = document.createElement('main'); const sourceHost = document.createElement('div')
  const bubble = document.createElement('div'); const slash = document.createElement('div')
  slash.append(document.createElement('button'))
  root.append(richHost, sourceHost, bubble, slash); document.body.append(root)
  let ui: EditorSelectionUI | undefined
  const rich = createEditor(richHost, markdown, follow => ui?.requestUpdate(follow))
  const source = createSource(sourceHost, markdown, () => {}, (_view, follow) => ui?.requestUpdate(follow))
  const entry: { rich: Editor; source: ReturnType<typeof createSourceEditor>; mode: 'rich' | 'source' | 'split' } = { rich, source, mode: 'rich' }
  let typewriter = false; let measurements = 0
  rich.view.coordsAtPos = () => { measurements++; return { left: 100, right: 100, top: 500, bottom: 520 } }
  richHost.getBoundingClientRect = () => new window.DOMRect(0, 0, 800, 600)
  ui = new SelectionUI({ active: () => entry, typewriter: () => typewriter, richHost, sourceHost, bubble, slash })
  rich.view.focus(); ui.dismiss()
  return { entry, rich, source, ui, root, richHost, bubble, slash,
    measurements: () => measurements,
    typewriter: (enabled: boolean) => { typewriter = enabled },
    destroy() { ui?.destroy(); rich.destroy(); source.view.destroy(); root.remove(); frames.clear() }
  }
}

test('长文章连续拖选不重扫标题或代码高亮，也不改变文章', t => {
  const content = '# 标题\n\n```js\nconst value = 1\n```\n\n' + Array.from({ length: 1200 }, (_, index) => `段落 ${index} 的正文内容。`).join('\n\n')
  const f = fixture(content)
  try {
    const original = f.rich.getJSON()
    const scan = t.mock.method(f.rich.state.doc, 'descendants')
    pointer(f.rich.view.dom, 'pointerdown')
    for (let index = 2; index < 302; index++) {
      if (f.rich.state.doc.resolve(index).parent.inlineContent) f.rich.commands.setTextSelection({ from: 1, to: index })
    }
    assert.equal(scan.mock.callCount(), 0, '纯选区事务不应扫描整篇文章')
    assert.equal(f.measurements(), 0)
    assert.equal(frames.size, 0)
    assert.deepEqual(f.rich.getJSON(), original)
  } finally { f.destroy() }
})

test('拖选期间不显示浮层、不滚动，松开后保留跨段落选区与复制内容', () => {
  const f = fixture()
  try {
    f.typewriter(true); f.richHost.scrollTop = 120
    const original = f.rich.getMarkdown()
    pointer(f.rich.view.dom, 'pointerdown')
    for (let to = 8; to < 40; to++) {
      if (f.rich.state.doc.resolve(to).parent.inlineContent) f.rich.commands.setTextSelection({ from: 6, to })
    }
    const selection = f.rich.state.selection.toJSON()
    const expected = f.rich.state.doc.textBetween(6, 39, '\n\n')
    flushFrames()
    assert.equal(f.measurements(), 0); assert.equal(f.richHost.scrollTop, 120)
    assert.equal(f.bubble.hidden, true)
    pointer(window, 'pointerup', 0); flushFrames()
    assert.equal(f.measurements(), 1); assert.equal(f.richHost.scrollTop, 120)
    assert.equal(f.bubble.hidden, false)
    assert.deepEqual(f.rich.state.selection.toJSON(), selection)
    const clipboard = f.rich.view.serializeForClipboard(f.rich.state.selection.content())
    assert.equal(clipboard.text, expected)
    assert.ok(clipboard.dom.querySelector('strong'))
    assert.equal(f.rich.getMarkdown(), original)
  } finally { f.destroy() }
})

test('反向拖选与键盘扩选不会触发打字机居中', () => {
  const f = fixture()
  try {
    f.typewriter(true); f.richHost.scrollTop = 100
    pointer(f.rich.view.dom, 'pointerdown')
    for (let to = 38; to > 6; to--) {
      if (f.rich.state.doc.resolve(to).parent.inlineContent) f.rich.commands.setTextSelection({ from: 39, to })
    }
    pointer(window, 'pointerup', 0); flushFrames()
    assert.equal(f.rich.state.selection.anchor, 39); assert.equal(f.rich.state.selection.head, 7)
    assert.equal(f.richHost.scrollTop, 100)
    f.rich.commands.setTextSelection({ from: 39, to: 6 }); flushFrames()
    assert.equal(f.richHost.scrollTop, 100)
    f.rich.commands.setTextSelection(6); flushFrames()
    assert.ok(f.richHost.scrollTop > 100, '折叠输入光标仍可跟随打字机定位')
  } finally { f.destroy() }
})

test('连续选区通知只刷新一次，不需要工具时不测量布局', () => {
  const f = fixture()
  try {
    for (let index = 0; index < 20; index++) f.ui.requestUpdate()
    assert.equal(frames.size, 1); flushFrames()
    assert.equal(f.measurements(), 0)
    f.rich.commands.setTextSelection({ from: 6, to: 10 })
    for (let index = 0; index < 20; index++) f.ui.requestUpdate()
    assert.equal(frames.size, 1); flushFrames()
    assert.equal(f.measurements(), 1)
    f.richHost.dispatchEvent(new window.Event('scroll')); flushFrames()
    assert.equal(f.measurements(), 2, '滚动后工具栏仍跟随选区')
    f.ui.requestUpdate(); f.ui.dismiss(); flushFrames()
    assert.equal(f.bubble.hidden, true, '关闭工具栏会取消待执行帧')
  } finally { f.destroy() }
})

test('失焦、取消拖选及窗口外松开后能够继续使用工具', () => {
  const f = fixture()
  try {
    for (const ending of ['pointercancel', 'pointermove', 'blur']) {
      pointer(f.rich.view.dom, 'pointerdown')
      f.rich.commands.setTextSelection({ from: 6, to: 10 })
      if (ending === 'blur') { window.dispatchEvent(new window.Event('blur')); f.ui.requestUpdate() }
      else pointer(window, ending, 0)
      flushFrames(); assert.equal(f.bubble.hidden, false)
    }
  } finally { f.destroy() }
})

test('斜杠菜单获得键盘焦点时保留菜单和输入选区', () => {
  const f = fixture('/')
  try {
    f.rich.commands.setTextSelection(2); flushFrames()
    assert.equal(f.slash.hidden, false)
    const selection = f.rich.state.selection.toJSON()
    f.slash.querySelector('button')!.focus(); flushFrames()
    assert.equal(f.slash.hidden, false)
    assert.deepEqual(f.rich.state.selection.toJSON(), selection)
    const input = document.createElement('input'); f.root.append(input); input.focus(); flushFrames()
    assert.equal(f.slash.hidden, true)
  } finally { f.destroy() }
})

test('源码和分栏的鼠标选择不滚动，键盘输入的折叠光标仍能居中', t => {
  const f = fixture()
  try {
    f.typewriter(true); f.entry.mode = 'source'; f.source.view.focus(); f.ui.dismiss()
    const dispatch = t.mock.method(f.source.view, 'dispatch')
    f.source.view.dispatch({ selection: { anchor: 5 }, userEvent: 'select.pointer' }); flushFrames()
    assert.equal(dispatch.mock.callCount(), 1, '鼠标点击不额外派发居中效果')
    pointer(f.source.view.contentDOM, 'pointerdown')
    f.source.view.dispatch({ selection: { anchor: 5, head: 30 }, userEvent: 'select.pointer' })
    pointer(window, 'pointerup', 0); flushFrames()
    assert.equal(dispatch.mock.callCount(), 2)
    f.entry.mode = 'split'
    f.source.view.dispatch({ selection: { anchor: 5, head: 32 }, userEvent: 'select' }); flushFrames()
    assert.equal(dispatch.mock.callCount(), 3)
    f.source.view.dispatch({ selection: { anchor: 32 }, userEvent: 'select' }); flushFrames()
    assert.equal(dispatch.mock.callCount(), 5, '键盘移动到折叠光标时派发一次居中效果')
    assert.equal(f.bubble.hidden, true)
  } finally { f.destroy() }
})

test('标题编辑、撤销和代码编辑仍更新锚点与语法高亮', () => {
  const f = fixture('# 重复标题\n\n# 重复标题\n\n```js\nconst value = 1\n```')
  try {
    const headings = () => [...f.rich.view.dom.querySelectorAll('h1')].map(node => node.id)
    assert.deepEqual(headings(), ['重复标题', '重复标题-1'])
    f.rich.commands.insertContentAt({ from: 1, to: 5 }, '新标题')
    assert.deepEqual(headings(), ['新标题', '重复标题'])
    assert.ok(f.rich.commands.undo()); assert.deepEqual(headings(), ['重复标题', '重复标题-1'])
    const code = f.rich.view.dom.querySelector('pre code')!
    assert.equal(code.querySelector('.hljs-keyword')?.textContent, 'const')
    let codeStart = 0
    f.rich.state.doc.descendants((node, pos) => { if (node.type.name === 'codeBlock') codeStart = pos + 1 })
    f.rich.commands.insertContentAt({ from: codeStart, to: codeStart + 5 }, 'let')
    assert.equal(code.querySelector('.hljs-keyword')?.textContent, 'let')
    assert.ok(f.rich.commands.undo()); assert.equal(code.querySelector('.hljs-keyword')?.textContent, 'const')
  } finally { f.destroy() }
})

test('段落高亮由编辑器装饰维护，同段移动不修改 DOM 属性', () => {
  const f = fixture('第一段内容。\n\n第二段内容。')
  try {
    f.rich.commands.setTextSelection(2)
    const observer = new MutationObserver(() => {})
    observer.observe(f.rich.view.dom, { attributes: true, subtree: true })
    f.rich.commands.setTextSelection(3)
    assert.equal(observer.takeRecords().filter(record => record.target !== f.rich.view.dom).length, 0)
    f.rich.commands.setTextSelection(10)
    assert.equal(f.rich.view.dom.querySelectorAll('.active-paragraph').length, 1)
    assert.equal(f.rich.view.dom.querySelector('.active-paragraph')?.textContent, '第二段内容。')
    observer.disconnect()
  } finally { f.destroy() }
})
