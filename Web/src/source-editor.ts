import { EditorState, Compartment } from '@codemirror/state'
import { EditorView, keymap, lineNumbers, highlightActiveLine } from '@codemirror/view'
import { markdown } from '@codemirror/lang-markdown'
import { defaultHighlightStyle, syntaxHighlighting, indentUnit } from '@codemirror/language'
import { history, historyKeymap, defaultKeymap, indentWithTab } from '@codemirror/commands'
import { search, searchKeymap, highlightSelectionMatches } from '@codemirror/search'
import { closeBrackets, closeBracketsKeymap } from '@codemirror/autocomplete'

export function createSourceEditor(parent: HTMLElement, content: string, onChange: (value: string) => void,
  onSelection: (view: EditorView) => void): { view: EditorView; numbers: Compartment } {
  const numbers = new Compartment()
  const view = new EditorView({
    parent,
    state: EditorState.create({ doc: content, extensions: [
      markdown(), syntaxHighlighting(defaultHighlightStyle), history(), search({ top: true }),
      highlightActiveLine(), highlightSelectionMatches(), closeBrackets(), EditorView.lineWrapping,
      indentUnit.of('  '), numbers.of(lineNumbers()),
      EditorState.phrases.of({ 'Find': '查找', 'Replace': '替换', 'next': '下一个', 'previous': '上一个',
        'all': '全部', 'replace': '替换', 'replace all': '全部替换', 'close': '关闭',
        'match case': '区分大小写', 'regexp': '正则', 'by word': '整词', 'Search': '搜索',
        'No matches': '没有匹配结果', 'replaced $ matches': '已替换 $ 处' }),
      keymap.of([...closeBracketsKeymap, ...defaultKeymap, ...historyKeymap, ...searchKeymap, indentWithTab]),
      EditorView.updateListener.of(update => {
        if (update.docChanged) onChange(update.state.doc.toString())
        if (update.selectionSet || update.docChanged) onSelection(view)
      }),
      EditorView.contentAttributes.of({ 'aria-label': 'Markdown 源码编辑器', spellcheck: 'false' })
    ] })
  })
  return { view, numbers }
}
