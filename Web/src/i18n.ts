import english from '../../Sources/Mori/Resources/Localization/en.json'

export type EditorLanguage = 'en' | 'zh-CN'
const catalog: Readonly<Record<string, string>> = english
let language: EditorLanguage = 'en'
export function editorLanguage(): EditorLanguage { return language }
export function t(key: string, target: EditorLanguage = language): string { return target === 'en' ? catalog[key] ?? key : key }

// ===== 只更新界面标签，不替换输入值、文档内容或编辑器实例 =====
export function localize(element: HTMLElement, labels: { text?: string; title?: string; aria?: string; placeholder?: string }): void {
  for (const [attribute, key] of Object.entries(labels)) element.setAttribute(`data-i18n-${attribute}`, key)
  updateElement(element)
}

function updateElement(element: HTMLElement): void {
  for (const attribute of ['text', 'title', 'aria', 'placeholder']) {
    const key = element.getAttribute(`data-i18n-${attribute}`)
    if (key === null) continue
    if (attribute === 'text') element.textContent = t(key)
    else element.setAttribute(attribute === 'aria' ? 'aria-label' : attribute, t(key))
  }
}

export function setEditorLanguage(value: EditorLanguage): void {
  const changed = language !== value
  language = value
  if (typeof document === 'undefined') return
  document.documentElement.lang = value; document.title = t('Mori 编辑器')
  for (const element of document.querySelectorAll<HTMLElement>('[data-i18n-text],[data-i18n-title],[data-i18n-aria],[data-i18n-placeholder]')) updateElement(element)
  if (changed) document.dispatchEvent(new CustomEvent('mori-language-change'))
}
