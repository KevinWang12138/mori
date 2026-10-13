import type { Editor } from '@tiptap/core'
import type { EditorView } from '@codemirror/view'
import { openSearchPanel } from '@codemirror/search'
import { undo, redo } from '@codemirror/commands'
import { safeLink } from './document'
import { editFields } from './dialogs'

export function formatRich(editor: Editor, name: string, payload: Record<string, unknown>): void {
  const chain = editor.chain().focus()
  switch (name) {
    case 'bold': chain.toggleBold().run(); break
    case 'italic': chain.toggleItalic().run(); break
    case 'strike': chain.toggleStrike().run(); break
    case 'code': chain.toggleCode().run(); break
    case 'heading1': chain.toggleHeading({ level: 1 }).run(); break
    case 'heading2': chain.toggleHeading({ level: 2 }).run(); break
    case 'heading3': chain.toggleHeading({ level: 3 }).run(); break
    case 'paragraph': chain.setParagraph().run(); break
    case 'bullet': chain.toggleBulletList().run(); break
    case 'ordered': chain.toggleOrderedList().run(); break
    case 'task': chain.toggleTaskList().run(); break
    case 'quote': chain.toggleBlockquote().run(); break
    case 'divider': chain.setHorizontalRule().run(); break
    case 'codeblock': chain.toggleCodeBlock({ language: 'text' }).run(); break
    case 'mermaid': chain.insertContent({ type: 'codeBlock', attrs: { language: 'mermaid' }, content: [{ type: 'text', text: 'flowchart LR\n  想法 --> 写作 --> 发布' }] }).run(); break
    case 'math': chain.insertContent({ type: 'blockMath', attrs: { latex: 'E = mc^2' } }).run(); break
    case 'table': chain.insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(); break
    case 'addRow': chain.addRowAfter().run(); break
    case 'addColumn': chain.addColumnAfter().run(); break
    case 'deleteRow': chain.deleteRow().run(); break
    case 'deleteColumn': chain.deleteColumn().run(); break
    case 'deleteTable': chain.deleteTable().run(); break
    case 'undo': chain.undo().run(); break
    case 'redo': chain.redo().run(); break
    case 'insertImage': chain.setImage({ src: String(payload.src), alt: String(payload.alt ?? '') }).run(); break
    case 'link': {
      const existing = editor.getAttributes('link').href as string | undefined
      editFields('链接', [{ label: '链接地址', value: existing ?? 'https://' }], values => {
        const href = safeLink(values[0])
        if (!values[0]) editor.chain().focus().extendMarkRange('link').unsetLink().run()
        else if (href) editor.chain().focus().extendMarkRange('link').setLink({ href }).run()
      }); break
    }
    case 'insertText': chain.insertContent(String(payload.text ?? ''), { contentType: 'markdown' }).run(); break
  }
}

export function formatSource(view: EditorView, name: string, payload: Record<string, unknown>): void {
  if (name === 'find') { openSearchPanel(view); return }
  if (name === 'undo') { undo(view); return }
  if (name === 'redo') { redo(view); return }
  const range = view.state.selection.main
  const text = view.state.sliceDoc(range.from, range.to)
  const wraps: Record<string, [string, string]> = { bold: ['**', '**'], italic: ['*', '*'], strike: ['~~', '~~'], code: ['`', '`'], link: ['[', '](https://)'] }
  let insert = ''
  let from = range.from
  let to = range.to
  let cursor = range.from
  if (wraps[name]) {
    const [before, after] = wraps[name]; insert = before + (text || '文字') + after; cursor = from + before.length
  } else {
    const blocks: Record<string, string> = {
      table: '\n| 标题 | 标题 |\n| --- | --- |\n| 内容 | 内容 |\n',
      codeblock: '\n```text\n' + (text || '代码') + '\n```\n',
      mermaid: '\n```mermaid\nflowchart LR\n  想法 --> 写作 --> 发布\n```\n',
      math: '\n$$\nE = mc^2\n$$\n', divider: '\n\n---\n\n',
      insertImage: `![${String(payload.alt ?? '')}](${String(payload.src ?? '').replaceAll(' ', '%20')})`,
      insertText: String(payload.text ?? '')
    }
    const prefixes: Record<string, string> = { heading1: '# ', heading2: '## ', heading3: '### ', bullet: '- ', ordered: '1. ', task: '- [ ] ', quote: '> ', paragraph: '' }
    if (name in prefixes) {
      const firstLine = view.state.doc.lineAt(range.from); const lastLine = view.state.doc.lineAt(range.to)
      from = firstLine.from; to = lastLine.to
      insert = view.state.sliceDoc(from, to).split('\n').map(line => prefixes[name] + line.replace(/^(?:#{1,6} |> |- |\d+\. |- \[[ x]\] )/, '')).join('\n')
    } else if (name in blocks) { insert = blocks[name] }
    else { return }
    cursor = from + insert.length
  }
  view.dispatch({ changes: { from, to, insert }, selection: { anchor: Math.min(from + insert.length, cursor) }, scrollIntoView: true })
  view.focus()
}
