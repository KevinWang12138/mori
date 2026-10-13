import type { Editor } from '@tiptap/core'
import { TextSelection } from '@tiptap/pm/state'
import type { Node as ProseMirrorNode } from '@tiptap/pm/model'

export interface InsertItem { name: string; label: string; symbol: string }
export const insertItems: InsertItem[] = [
  { name: 'heading1', label: '一级标题', symbol: 'H1' }, { name: 'heading2', label: '二级标题', symbol: 'H2' },
  { name: 'bullet', label: '无序列表', symbol: '•' }, { name: 'ordered', label: '有序列表', symbol: '1.' },
  { name: 'task', label: '任务清单', symbol: '☑' }, { name: 'quote', label: '引用', symbol: '❞' },
  { name: 'table', label: '表格', symbol: '▦' }, { name: 'codeblock', label: '代码块', symbol: '</>' },
  { name: 'math', label: '公式', symbol: '∑' }, { name: 'mermaid', label: 'Mermaid 图表', symbol: '◇' },
  { name: 'divider', label: '分隔线', symbol: '—' }
]

export interface SearchMatch { from: number; to: number }

// ===== 跨内联格式匹配正文，把文本索引映射回编辑器位置 =====
export function findMatches(doc: ProseMirrorNode, query: string, caseSensitive = false): SearchMatch[] {
  if (!query) return []
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const expression = new RegExp(escaped, caseSensitive ? 'gu' : 'giu')
  const matches: SearchMatch[] = []
  doc.descendants((node, pos) => {
    if (!node.isTextblock) return
    const text = node.textBetween(0, node.content.size, '', '\uFFFC')
    for (const match of text.matchAll(expression)) matches.push({ from: pos + 1 + match.index, to: pos + 1 + match.index + match[0].length })
    return false
  })
  return matches
}

// ===== 查找面板支持前后导航、逐处替换、全部替换与撤销 =====
export function findInRich(editor: Editor): void {
  const existing = document.querySelector<HTMLElement>('.find-panel')
  if (existing) { existing.querySelector<HTMLInputElement>('input')?.focus(); return }
  const panel = document.createElement('section'); panel.className = 'find-panel'; panel.setAttribute('aria-label', '查找与替换')
  const search = document.createElement('input'); search.placeholder = '查找内容'; search.setAttribute('aria-label', '查找内容')
  const replace = document.createElement('input'); replace.placeholder = '替换为'; replace.setAttribute('aria-label', '替换为')
  const count = document.createElement('span'); count.className = 'find-count'
  const sensitive = document.createElement('input'); sensitive.type = 'checkbox'
  const sensitiveLabel = document.createElement('label'); sensitiveLabel.append(sensitive, '区分大小写')
  let matches: SearchMatch[] = []; let index = -1
  const refresh = () => {
    matches = findMatches(editor.state.doc, search.value, sensitive.checked)
    if (index >= matches.length) index = matches.length - 1
    count.textContent = search.value ? (matches.length ? `${Math.max(0, index + 1)} / ${matches.length}` : '没有匹配') : ''
  }
  const jump = (direction: number) => {
    refresh(); if (!matches.length) return
    index = (index + direction + matches.length) % matches.length
    const match = matches[index]
    editor.view.dispatch(editor.state.tr.setSelection(TextSelection.create(editor.state.doc, match.from, match.to)).scrollIntoView())
    count.textContent = `${index + 1} / ${matches.length}`
  }
  const button = (label: string, action: () => void) => {
    const result = document.createElement('button'); result.textContent = label; result.type = 'button'; result.onclick = action; return result
  }
  const first = document.createElement('div'); first.append(search, count, button('↑', () => jump(-1)), button('↓', () => jump(1)), button('关闭', () => { panel.remove(); editor.commands.focus() }))
  const second = document.createElement('div'); second.append(replace,
    button('替换', () => {
      refresh(); const match = matches[Math.max(0, index)]; if (!match) return
      editor.view.dispatch(editor.state.tr.insertText(replace.value, match.from, match.to)); refresh(); jump(1)
    }), button('全部替换', () => {
      refresh(); const transaction = editor.state.tr
      for (const match of [...matches].reverse()) transaction.insertText(replace.value, match.from, match.to)
      editor.view.dispatch(transaction); index = -1; refresh()
    }), sensitiveLabel)
  search.oninput = () => { index = -1; refresh() }
  sensitive.onchange = () => { index = -1; refresh() }
  search.onkeydown = event => {
    if (event.key === 'Enter') { event.preventDefault(); jump(event.shiftKey ? -1 : 1) }
    if (event.key === 'Escape') { panel.remove(); editor.commands.focus() }
  }
  panel.append(first, second); document.body.append(panel); search.focus()
}
