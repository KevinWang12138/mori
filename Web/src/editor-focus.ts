import type { Editor } from '@tiptap/core'
import type { EditorView } from '@codemirror/view'

// ===== 新建文章从空白正文开始，切回已有文章保留原来的选区 =====
export function focusDocument(rich: Editor, source: EditorView, mode: 'rich' | 'source' | 'split', startsInBody: boolean): void {
  if (mode === 'rich') {
    if (startsInBody && rich.state.doc.lastChild?.type.name !== 'paragraph') {
      rich.commands.insertContentAt(rich.state.doc.content.size, { type: 'paragraph' }, { updateSelection: false })
    }
    rich.commands.focus(startsInBody ? 'end' : undefined)
  } else {
    if (startsInBody) source.dispatch({ selection: { anchor: source.state.doc.length }, scrollIntoView: true })
    source.focus()
  }
}
