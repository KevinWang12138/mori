import { test } from 'node:test'
import assert from 'node:assert/strict'
import { splitFrontMatter, requiresSourceMode, safeLink, assetURL } from '../src/document'

test('元信息保留注释、未知字段、CRLF 与原始正文', () => {
  const source = '---\r\n# keep\r\ntitle: Blog\r\ncustom:\r\n  nested: true\r\n...\r\n\r\n# Body\r\n'
  const parts = splitFrontMatter(source)
  assert.equal(parts.prefix + parts.body, source)
  assert.equal(parts.body, '\r\n# Body\r\n')
  assert.ok(parts.yaml.includes('custom:\r\n  nested: true'))
  assert.equal(splitFrontMatter('---\nnot closed').body, '---\nnot closed')
})

test('扩展语法使用源码模式保护文章', () => {
  for (const text of ['Text[^1]\n\n[^1]: footnote', '<Callout>hello</Callout>', '[label]: /address\n\n[label]', 'import X from "x"\n\n<X />', ':::tip\nhello\n:::', '[TOC]', '    indented code', '![image](pic.png) trailing text']) assert.ok(requiresSourceMode(text), text)
  for (const text of ['# 标题\n\n正文 **加粗**', '- [x] 完成', '| a | b |\n|---|---|\n| 1 | 2 |', '```html\n<div>code only</div>\n```', '$E=mc^2$', '$$\na+b\n$$']) assert.equal(requiresSourceMode(text), false, text)
})

test('HTML 注释和闭合标签原样保留，代码块内的相同文本不影响写作模式', () => {
  for (const text of ['正文\n<!-- 发布前备注 -->', '</Custom>', '<?instruction value?>', '<!DOCTYPE html>']) {
    assert.equal(requiresSourceMode(text), true, text)
    assert.equal(requiresSourceMode('```html\n' + text + '\n```'), false, text)
  }
})

test('更长的闭合围栏之后仍检查扩展语法，较短或不同围栏不会提前闭合', () => {
  assert.equal(requiresSourceMode('```text\n示例\n````\n\n[^note]: 正文脚注'), true)
  assert.equal(requiresSourceMode('~~~text\n示例\n~~~~\n\n<!-- 正文注释 -->'), true)
  assert.equal(requiresSourceMode('````text\n```\n<!-- 代码 -->\n````'), false)
  assert.equal(requiresSourceMode('```text\n~~~\n<div>代码</div>\n```'), false)
})

test('链接拒绝执行脚本和隐式协议', () => {
  assert.equal(safeLink('javascript:alert(1)'), null)
  assert.equal(safeLink('file:///etc/passwd'), null)
  assert.equal(safeLink('//unknown.example'), null)
  assert.equal(safeLink(' https://example.com '), 'https://example.com')
  assert.equal(safeLink('../posts/hello.md'), '../posts/hello.md')
})

test('图片使用本机限定的资源通道，支持中文和空格路径', () => {
  assert.equal(assetURL('assets/你好%20world.png', '/blog'), 'mori-asset://local/blog/assets/%E4%BD%A0%E5%A5%BD%20world.png')
  assert.equal(assetURL('https://example.com/pic.png', '/blog'), 'https://example.com/pic.png')
  assert.equal(assetURL('javascript:alert(1)', '/blog'), '')
  assert.equal(assetURL('file:///etc/passwd', '/blog'), '')
})
