import { Extension } from '@tiptap/core'
import { Plugin, PluginKey, type EditorState } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import type { Node } from '@tiptap/pm/model'
import { headingID } from './document'

// ===== 标题锚点只随文档内容重建，选区和焦点变化复用缓存 =====
function headingDecorations(doc: Node): DecorationSet {
  const seen = new Map<string, number>(); const decorations: Decoration[] = []
  doc.descendants((node, position) => {
    if (node.type.name === 'heading') decorations.push(Decoration.node(position, position + node.nodeSize, { id: headingID(node.textContent, seen) }))
  })
  return DecorationSet.create(doc, decorations)
}

export const HeadingAnchors = Extension.create({
  name: 'headingAnchors',
  addProseMirrorPlugins() {
    const key = new PluginKey<DecorationSet>('mori-heading-anchors')
    return [new Plugin({
      key,
      state: {
        init: (_, state) => headingDecorations(state.doc),
        apply: (transaction, previous) => transaction.docChanged ? headingDecorations(transaction.doc) : previous
      },
      props: { decorations: state => key.getState(state) }
    })]
  }
})

interface ActiveBlock { from: number; to: number; decorations: DecorationSet }

// ===== 只定位选区起点所在的顶层段落，避免逐段修改编辑器 DOM =====
function activeBlock(state: EditorState, previous?: ActiveBlock): ActiveBlock {
  const { $from } = state.selection
  const node = $from.depth > 0 ? $from.node(1) : $from.nodeAfter
  const from = $from.depth > 0 ? $from.before(1) : $from.pos
  const to = from + (node?.nodeSize ?? 0)
  if (previous?.from === from && previous.to === to) return previous
  return { from, to, decorations: node ? DecorationSet.create(state.doc, [Decoration.node(from, to, { class: 'active-paragraph' })]) : DecorationSet.empty }
}

export const FocusParagraph = Extension.create({
  name: 'focusParagraph',
  addProseMirrorPlugins() {
    const key = new PluginKey<ActiveBlock>('mori-focus-paragraph')
    return [new Plugin({
      key,
      state: {
        init: (_, state) => activeBlock(state),
        apply: (transaction, previous, _, state) => transaction.docChanged ? activeBlock(state)
          : transaction.selectionSet ? activeBlock(state, previous) : previous
      },
      props: { decorations: state => key.getState(state)?.decorations }
    })]
  }
})
