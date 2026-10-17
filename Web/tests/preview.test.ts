import { test } from 'node:test'
import assert from 'node:assert/strict'
import { ArticlePreview } from '../src/article-preview'

// ===== 受控异步渲染模拟图表耗时，验证提交顺序与销毁行为 =====
function fixture() {
  const renders: { markdown: string; directory: string; dark: boolean; resolve: (value: HTMLElement) => void; reject: (error: Error) => void }[] = []
  const commits: HTMLElement[] = []
  let errors = 0
  const preview = new ArticlePreview(content => new Promise((resolve, reject) => renders.push({ ...content, resolve, reject })),
    article => commits.push(article), () => { errors++ })
  return { preview, renders, commits, errors: () => errors }
}

test('新输入在防抖开始时作废旧结果，快速输入只渲染最后一份', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const f = fixture()
  f.preview.schedule({ markdown: '旧文章', directory: '/old', dark: false })
  t.mock.timers.tick(120)
  f.preview.schedule({ markdown: '中间内容', directory: '/new', dark: false })
  f.preview.schedule({ markdown: '最新内容', directory: '/new', dark: true })
  f.renders[0].resolve({} as HTMLElement); await Promise.resolve()
  assert.equal(f.commits.length, 0)
  t.mock.timers.tick(120)
  assert.equal(f.renders.length, 2)
  assert.equal(f.renders[1].markdown, '最新内容')
  assert.equal(f.renders[1].directory, '/new'); assert.equal(f.renders[1].dark, true)
  const article = {} as HTMLElement
  f.renders[1].resolve(article); await Promise.resolve()
  assert.deepEqual(f.commits, [article])
})

test('取消预览后不启动排队渲染，也不提交仍在运行的结果', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const f = fixture()
  f.preview.schedule({ markdown: '排队中', directory: '', dark: false }); f.preview.cancel()
  t.mock.timers.tick(120); assert.equal(f.renders.length, 0)
  f.preview.schedule({ markdown: '运行中', directory: '', dark: false }); t.mock.timers.tick(120)
  f.preview.cancel(); f.renders[0].resolve({} as HTMLElement); await Promise.resolve()
  assert.equal(f.commits.length, 0)
})

test('异步错误只报告当前预览，旧任务失败不干扰新文章', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const f = fixture()
  for (const current of [false, true]) {
    f.preview.schedule({ markdown: '内容', directory: '', dark: false }); t.mock.timers.tick(120)
    if (!current) f.preview.cancel()
    f.renders.at(-1)!.reject(new Error('render failed')); await Promise.resolve()
    assert.equal(f.errors(), current ? 1 : 0)
  }
})
