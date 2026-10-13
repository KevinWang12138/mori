export interface FrontMatterParts { prefix: string; yaml: string; body: string }

// ===== 从正文分离原始元信息，编辑正文时不重写 YAML =====
export function splitFrontMatter(markdown: string): FrontMatterParts {
  const match = markdown.match(/^---[ \t]*\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|$)/)
  return match ? { prefix: match[0], yaml: match[1], body: markdown.slice(match[0].length) }
    : { prefix: '', yaml: '', body: markdown }
}

// ===== 扩展语法交给源码编辑，避免富文本序列化损失用户内容 =====
export function requiresSourceMode(markdown: string): boolean {
  const body = splitFrontMatter(markdown).body.replace(/(^|\n) {0,3}(`{3,}|~{3,})[^\n]*\n[\s\S]*?(?:\n {0,3}\2[ \t]*(?=\n|$)|$)/g, '')
  return /(^|\n)\s*\[\^[^\]]+\]:/.test(body)
    || /\[\^[^\]]+\]/.test(body)
    || /(^|\n) {0,3}\[[^\]]+\]:[ \t]*\S/.test(body)
    || /(^|\n)\s*(?:import\s|export\s|:::+)/.test(body)
    || /<[A-Za-z][\w-]*(?:\s|\/?>)/.test(body)
    || /(^|\n)\+\+\+\s*\n/.test(body)
    || /(^|\n)\s*\[TOC\]\s*(?=\n|$)/i.test(body)
    || /(^|\n) {4}\S/.test(body)
    || /!\[[^\]]*\]\([^\n]+\).*\S/.test(body)
}

export function safeLink(value: string): string | null {
  const trimmed = value.trim()
  if (/^(?:https?:\/\/|mailto:|#)/i.test(trimmed)) return trimmed
  if (!/^[a-z][a-z\d+.-]*:/i.test(trimmed) && !trimmed.startsWith('//') && !trimmed.includes('\0')) return trimmed
  return null
}

export function assetURL(value: string, directory: string): string {
  if (/^(https:\/\/|data:image\/|mori-asset:)/i.test(value)) return value
  if (/^[a-z][a-z\d+.-]*:/i.test(value) || value.startsWith('//')) return ''
  const path = value.startsWith('/') ? value : `${directory}/${decodeSafe(value)}`
  return `mori-asset://local${path.split('/').map(encodeURIComponent).join('/')}`
}

export function headingID(title: string, seen: Map<string, number>): string {
  const base = title.toLocaleLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s+/g, '-').trim() || 'section'
  const count = seen.get(base) ?? 0; seen.set(base, count + 1)
  return count ? `${base}-${count}` : base
}

function decodeSafe(value: string): string {
  try { return decodeURIComponent(value) } catch { return value }
}
