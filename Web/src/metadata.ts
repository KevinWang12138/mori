import { parseDocument, isMap } from 'yaml'
import { splitFrontMatter } from './document'

const strings = new Set(['title', 'description', 'date', 'pubDate', 'slug', 'layout', 'cover', 'heroImage'])
const arrays = new Set(['tags', 'categories'])

export function readMetadata(markdown: string): Record<string, unknown> {
  const yaml = parseDocument(splitFrontMatter(markdown).yaml)
  if (yaml.errors.length || !isMap(yaml.contents)) return {}
  const value: unknown = yaml.toJSON()
  return typeof value === 'object' && value !== null ? value as Record<string, unknown> : {}
}

// ===== 只修改明确提交的字段，保留未知字段、嵌套结构、注释与正文 =====
export function updateMetadata(markdown: string, updates: Record<string, unknown>): string | null {
  const parts = splitFrontMatter(markdown)
  const yaml = parseDocument(parts.yaml || '', { keepSourceTokens: true })
  if (yaml.errors.length || (yaml.contents && !isMap(yaml.contents))) return null
  for (const [key, value] of Object.entries(updates)) {
    if (strings.has(key) && typeof value === 'string') yaml.set(key, value)
    else if (arrays.has(key) && Array.isArray(value) && value.every(item => typeof item === 'string')) yaml.set(key, value)
    else if (key === 'draft' && typeof value === 'boolean') yaml.set(key, value)
  }
  return `---\n${yaml.toString()}---\n${parts.prefix ? '' : '\n'}${parts.body}`
}
