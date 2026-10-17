import { EditorState, Compartment, type StateEffect } from '@codemirror/state'
import { EditorView, keymap, lineNumbers, highlightActiveLine } from '@codemirror/view'
import { markdown } from '@codemirror/lang-markdown'
import { defaultHighlightStyle, syntaxHighlighting, indentUnit } from '@codemirror/language'
import { history, historyKeymap, defaultKeymap, indentWithTab } from '@codemirror/commands'
import { search, searchKeymap, highlightSelectionMatches } from '@codemirror/search'
import { closeBrackets, closeBracketsKeymap } from '@codemirror/autocomplete'
import { editorLanguage, type EditorLanguage, t } from './i18n'

export function sourceLanguageExtension(language: EditorLanguage) {
  return [EditorState.phrases.of(language === 'zh-CN' ? {
    'Find': '查找', 'Replace': '替换', 'next': '下一个', 'previous': '上一个',
    'all': '全部', 'replace': '替换', 'replace all': '全部替换', 'close': '关闭',
    'match case': '区分大小写', 'regexp': '正则', 'by word': '整词', 'Search': '搜索',
    'No matches': '没有匹配结果', 'replaced $ matches': '已替换 $ 处',
    'Go to line': '跳转到行', 'go': '跳转', 'current match': '当前匹配',
    'on line': '所在行', 'replaced match on line $': '已替换第 $ 行的匹配'
  } : {}), EditorView.contentAttributes.of({ 'aria-label': t('Markdown 源码编辑器', language), spellcheck: 'false' })]
}

// ===== 刷新已打开的源码查找面板，保留输入与选项，不重建面板 =====
export function localizeSourceSearch(view: EditorView): void {
  const panel = view.dom.querySelector<HTMLElement>('.cm-search')
  if (!panel) return
  for (const [name, key] of [['search', 'Find'], ['replace', 'Replace']]) {
    const input = panel.querySelector<HTMLInputElement>(`input[name="${name}"]`)
    if (input) { input.placeholder = view.state.phrase(key); input.setAttribute('aria-label', view.state.phrase(key)) }
  }
  for (const [name, key] of [['next', 'next'], ['prev', 'previous'], ['select', 'all'], ['replace', 'replace'], ['replaceAll', 'replace all']]) {
    const button = panel.querySelector<HTMLButtonElement>(`button[name="${name}"]`)
    if (button) button.textContent = view.state.phrase(key)
  }
  for (const [name, key] of [['case', 'match case'], ['re', 'regexp'], ['word', 'by word']]) {
    const label = panel.querySelector<HTMLInputElement>(`input[name="${name}"]`)?.parentElement
    if (!label) continue
    for (const node of label.childNodes) if (node.nodeType === 3) node.textContent = view.state.phrase(key)
  }
  panel.querySelector('button[name="close"]')?.setAttribute('aria-label', view.state.phrase('close'))
}

// ===== 语言重配置时保存查找面板尚未提交的输入和选择位置 =====
export function configureSourceLanguage(view: EditorView, compartment: Compartment, language: EditorLanguage,
  effects: StateEffect<unknown>[] = []): void {
  const fields = [...view.dom.querySelectorAll<HTMLInputElement>('.cm-search input')].map(input => ({
    name: input.name, value: input.value, checked: input.checked, start: input.selectionStart, end: input.selectionEnd,
    focused: document.activeElement === input
  }))
  view.dispatch({ effects: [compartment.reconfigure(sourceLanguageExtension(language)), ...effects] })
  localizeSourceSearch(view)
  for (const field of fields) {
    const input = view.dom.querySelector<HTMLInputElement>(`.cm-search input[name="${field.name}"]`)
    if (!input) continue
    input.value = field.value; input.checked = field.checked
    if (field.focused) input.focus({ preventScroll: true })
    if (field.start !== null && field.end !== null) input.setSelectionRange(field.start, field.end)
  }
}

export function createSourceEditor(parent: HTMLElement, content: string, onChange: (value: string) => void,
  onSelection: (view: EditorView, followCaret: boolean) => void): { view: EditorView; numbers: Compartment; language: Compartment; editable: Compartment } {
  const numbers = new Compartment()
  const language = new Compartment()
  const editable = new Compartment()
  const view = new EditorView({
    parent,
    state: EditorState.create({ doc: content, extensions: [
      markdown(), syntaxHighlighting(defaultHighlightStyle), history(), search({ top: true }),
      highlightActiveLine(), highlightSelectionMatches(), closeBrackets(), EditorView.lineWrapping,
      indentUnit.of('  '), numbers.of(lineNumbers()), editable.of(EditorView.editable.of(true)),
      language.of(sourceLanguageExtension(editorLanguage())),
      keymap.of([...closeBracketsKeymap, ...defaultKeymap, ...historyKeymap, ...searchKeymap, indentWithTab]),
      EditorView.updateListener.of(update => {
        if (update.docChanged) onChange(update.state.doc.toString())
        if (update.selectionSet || update.docChanged) onSelection(view, !update.transactions.some(transaction => transaction.isUserEvent('select.pointer')))
      })
    ] })
  })
  return { view, numbers, language, editable }
}
