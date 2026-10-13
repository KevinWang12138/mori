declare module 'markdown-it-task-lists' {
  import type { PluginWithOptions } from 'markdown-it'
  const plugin: PluginWithOptions<{ enabled?: boolean; label?: boolean; labelAfter?: boolean }>
  export default plugin
}
declare module 'markdown-it-footnote' {
  import type { PluginSimple } from 'markdown-it'
  const plugin: PluginSimple
  export default plugin
}
declare module 'markdown-it-texmath' {
  import type { PluginWithOptions } from 'markdown-it'
  import type katex from 'katex'
  const plugin: PluginWithOptions<{ engine: typeof katex; delimiters?: string; katexOptions?: object }>
  export default plugin
}
