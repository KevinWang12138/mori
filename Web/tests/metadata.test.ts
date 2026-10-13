import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readMetadata, updateMetadata } from '../src/metadata'
import { splitFrontMatter } from '../src/document'

test('编辑标题保留多行摘要、标签、未知嵌套字段与正文', () => {
  const source = '---\n# comment\ntitle: "Old"\ndescription: |\n  First line\n  Second line\ntags:\n  - 写作\n  - markdown\ncustom:\n  color: green\n  values: [1, 2]\n---\n\n# 正文\n\n保留 **格式**。\n'
  const changed = updateMetadata(source, { title: 'New: title' })!
  const metadata = readMetadata(changed)
  assert.equal(metadata.title, 'New: title')
  assert.deepEqual(metadata.tags, ['写作', 'markdown'])
  assert.equal(metadata.description, 'First line\nSecond line\n')
  assert.deepEqual(metadata.custom, { color: 'green', values: [1, 2] })
  assert.ok(changed.includes('# comment'))
  assert.equal(splitFrontMatter(changed).body, splitFrontMatter(source).body)
})

test('无元信息的文章可以添加博客字段', () => {
  const changed = updateMetadata('# Hello\n\nBody', { title: 'Hello', draft: true, tags: ['blog'] })!
  assert.equal(readMetadata(changed).title, 'Hello')
  assert.equal(readMetadata(changed).draft, true)
  assert.ok(changed.endsWith('# Hello\n\nBody'))
})

test('无效 YAML 不被覆写，不接受未知字段和错误字段类型', () => {
  assert.equal(updateMetadata('---\ntitle: [invalid\n---\n\nBody', { title: 'replace' }), null)
  const changed = updateMetadata('---\ntitle: Old\n---\n\nBody', { title: { nested: true }, unrecognized: 'new', tags: [123] })!
  assert.equal(readMetadata(changed).title, 'Old')
  assert.equal(readMetadata(changed).unrecognized, undefined)
  assert.equal(readMetadata(changed).tags, undefined)
})
