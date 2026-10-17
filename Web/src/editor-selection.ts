import type { Editor } from '@tiptap/core'
import { EditorView } from '@codemirror/view'
import type { DocumentPayload } from './bridge'
import { insertItems } from './writing-tools'
import { t } from './i18n'

interface SelectionDocument {
  rich: Editor
  source: { view: EditorView }
  mode: DocumentPayload['mode']
}

interface SelectionOptions {
  active: () => SelectionDocument | undefined
  typewriter: () => boolean
  richHost: HTMLElement
  sourceHost: HTMLElement
  bubble: HTMLElement
  slash: HTMLElement
}

export class EditorSelectionUI {
  private frame?: number
  private pointer?: number
  private pending?: SelectionDocument
  private followCaret = false

  constructor(private readonly options: SelectionOptions) {
    window.addEventListener('pointerdown', this.pointerDown, true)
    window.addEventListener('pointerup', this.pointerEnd, true)
    window.addEventListener('pointercancel', this.pointerEnd, true)
    window.addEventListener('pointermove', this.pointerMove, true)
    window.addEventListener('blur', this.blur)
    window.addEventListener('resize', this.refresh)
    options.richHost.addEventListener('scroll', this.refresh, { passive: true })
    options.richHost.addEventListener('focusin', this.refresh)
    options.richHost.addEventListener('focusout', this.refresh)
    options.bubble.addEventListener('focusout', this.refresh)
    options.slash.addEventListener('focusout', this.refresh)
  }

  // ===== 合并一帧内的选区通知，拖选期间不测量布局或安排自动滚动 =====
  requestUpdate(followCaret = false): void {
    if (this.pointer !== undefined) return
    const entry = this.options.active()
    if (!entry) { this.dismiss(); return }
    if (this.pending !== entry) this.followCaret = false
    this.pending = entry; this.followCaret ||= followCaret
    if (this.frame !== undefined) return
    this.frame = requestAnimationFrame(() => {
      this.frame = undefined
      const pending = this.pending; const follow = this.followCaret
      this.pending = undefined; this.followCaret = false
      if (pending && pending === this.options.active() && this.pointer === undefined) this.update(pending, follow)
    })
  }

  // ===== 取消过时的浮层和滚动任务，保留编辑器自己的原生选区 =====
  dismiss(): void {
    if (this.frame !== undefined) cancelAnimationFrame(this.frame)
    this.frame = undefined; this.pending = undefined; this.followCaret = false
    this.options.bubble.hidden = true; this.options.slash.hidden = true
  }

  // ===== 释放监听与待执行帧 =====
  destroy(): void {
    this.dismiss()
    window.removeEventListener('pointerdown', this.pointerDown, true)
    window.removeEventListener('pointerup', this.pointerEnd, true)
    window.removeEventListener('pointercancel', this.pointerEnd, true)
    window.removeEventListener('pointermove', this.pointerMove, true)
    window.removeEventListener('blur', this.blur)
    window.removeEventListener('resize', this.refresh)
    this.options.richHost.removeEventListener('scroll', this.refresh)
    this.options.richHost.removeEventListener('focusin', this.refresh)
    this.options.richHost.removeEventListener('focusout', this.refresh)
    this.options.bubble.removeEventListener('focusout', this.refresh)
    this.options.slash.removeEventListener('focusout', this.refresh)
  }

  // ===== 鼠标按下后暂缓浮层，避免浮层遮住向上拖选的文字 =====
  private pointerDown = (event: PointerEvent): void => {
    if (event.button !== 0 || !(event.target instanceof Node)) return
    if (!this.options.richHost.contains(event.target) && !this.options.sourceHost.contains(event.target)) return
    this.pointer = event.pointerId; this.dismiss()
  }

  // ===== 松开或取消拖选后刷新工具，不把鼠标点击当成打字机定位 =====
  private pointerEnd = (event: PointerEvent): void => {
    if (this.pointer === undefined || event.pointerId !== this.pointer) return
    this.pointer = undefined; this.requestUpdate()
  }

  // ===== 鼠标在窗口外松开后，重新进入编辑器时恢复工具更新 =====
  private pointerMove = (event: PointerEvent): void => {
    if (event.buttons === 0) this.pointerEnd(event)
  }

  // ===== 窗口失焦时清除拖选状态与延迟任务 =====
  private blur = (): void => { this.pointer = undefined; this.dismiss() }

  // ===== 视口或焦点变化只更新浮层位置 =====
  private refresh = (): void => { this.requestUpdate() }

  // ===== 仅为实际显示的工具测量位置，自动居中只跟随折叠的输入光标 =====
  private update(entry: SelectionDocument, followCaret: boolean): void {
    const { bubble, slash, richHost } = this.options
    if (entry.mode !== 'rich') {
      bubble.hidden = true; slash.hidden = true
      const view = entry.source.view
      if (followCaret && this.options.typewriter() && view.hasFocus && view.state.selection.ranges.every(range => range.empty)) {
        view.dispatch({ effects: EditorView.scrollIntoView(view.state.selection.main.head, { y: 'center' }) })
      }
      return
    }
    const editor = entry.rich
    if (editor.isDestroyed) { bubble.hidden = true; slash.hidden = true; return }
    if (!editor.view.hasFocus()) {
      if (!bubble.contains(document.activeElement) && !slash.contains(document.activeElement)) {
        bubble.hidden = true; slash.hidden = true
      }
      return
    }
    const { from, empty, $from } = editor.state.selection
    if (followCaret && empty && this.options.typewriter()) {
      const caret = editor.view.coordsAtPos(from)
      const bounds = richHost.getBoundingClientRect()
      const offset = caret.top - bounds.top - bounds.height * 0.42
      if (Math.abs(offset) > 1) richHost.scrollTop += offset
    }
    const showBubble = !empty && !editor.isActive('codeBlock')
    const text = $from.parent.textContent
    const showSlash = empty && $from.parent.isTextblock && /^\/[\p{L}\p{N}]*$/u.test(text)
    const coords = showBubble || showSlash ? editor.view.coordsAtPos(from) : undefined
    bubble.hidden = !showBubble; slash.hidden = !showSlash
    if (!coords) return
    if (showBubble) {
      bubble.style.top = `${Math.max(4, coords.top - 46)}px`
      bubble.style.left = `${Math.max(8, Math.min(window.innerWidth - 230, coords.left))}px`
    }
    if (showSlash) {
      const query = text.slice(1).toLocaleLowerCase()
      for (const [index, child] of [...slash.children].entries()) {
        (child as HTMLElement).hidden = !!query && !t(insertItems[index].label).toLocaleLowerCase().includes(query) && !insertItems[index].name.includes(query)
      }
      slash.style.top = `${Math.min(window.innerHeight - 360, coords.bottom + 10)}px`
      slash.style.left = `${Math.min(window.innerWidth - 230, Math.max(8, coords.left))}px`
    }
  }
}
