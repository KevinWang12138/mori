import { test, before } from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
let render: (markdown: string, directory?: string) => string

before(async () => {
  const dom = new JSDOM('<!doctype html><html><body></body></html>')
  for (const key of ['window', 'document', 'Node', 'HTMLElement', 'Element', 'DOMParser']) {
    Object.defineProperty(globalThis, key, { value: Reflect.get(dom.window, key), configurable: true })
  }
  render = (await import('../src/renderer')).renderMarkdown
})

test('预览支持脚注、任务、表格与公式，同时排除元信息', () => {
  const source = '---\ntitle: metadata-only\n---\n\n# Heading\n\n- [x] task\n\n| a | b |\n|---|---|\n|1|2|\n\nText[^1].\n\n[^1]: footnote\n\n$$\na^2 + b^2 = c^2\n$$'
  const html = render(source)
  assert.ok(html.includes('<h1 id="heading">Heading</h1>'))
  assert.ok(html.includes('<table>'))
  assert.ok(html.includes('checkbox'))
  assert.ok(html.includes('footnote'))
  assert.ok(html.includes('katex'))
  assert.ok(html.includes('style="height:'))
  assert.equal(html.includes('metadata-only'), false)
})

test('本地图片正常映射，脚本与越权协议被去除', () => {
  const html = render('![picture](assets/photo.png)\n\n<script>alert(1)</script>\n\n<img src="x" onerror="alert(1)" style="position:fixed">\n\n[bad](javascript:alert(1))', '/blog')
  assert.ok(html.includes('mori-asset://local/blog/assets/photo.png'))
  assert.equal(html.includes('<script'), false)
  assert.equal(html.includes('onerror'), false)
  assert.equal(html.includes('position:fixed'), false)
  assert.equal(html.includes('href="javascript:'), false)
})
