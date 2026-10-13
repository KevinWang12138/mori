import MarkdownIt from 'markdown-it'
import footnote from 'markdown-it-footnote'
import tasks from 'markdown-it-task-lists'
import texmath from 'markdown-it-texmath'
import katex from 'katex'
import hljs from 'highlight.js'
import DOMPurify from 'dompurify'
import mermaid from 'mermaid'
import { assetURL, safeLink, splitFrontMatter, headingID } from './document'

const md: MarkdownIt = new MarkdownIt({ html: true, linkify: true, typographer: false,
  highlight(code, language): string {
    if (language && hljs.getLanguage(language)) return hljs.highlight(code, { language }).value
    return md.utils.escapeHtml(code)
  }
}).use(footnote).use(tasks, { enabled: false }).use(texmath, { engine: katex, delimiters: 'dollars', katexOptions: { throwOnError: false, trust: false, strict: 'ignore' } })

const originalImage = md.renderer.rules.image!
md.renderer.rules.image = (tokens, index, options, environment: { directory?: string }, self) => {
  const src = tokens[index].attrGet('src') ?? ''
  tokens[index].attrSet('src', assetURL(src, environment.directory ?? ''))
  return originalImage(tokens, index, options, environment, self)
}

const originalLink = md.renderer.rules.link_open ?? ((tokens, index, options, _environment, self) => self.renderToken(tokens, index, options))
md.renderer.rules.link_open = (tokens, index, options, environment, self) => {
  const href = tokens[index].attrGet('href') ?? ''
  tokens[index].attrSet('href', safeLink(href) ?? '#')
  tokens[index].attrSet('rel', 'noreferrer noopener')
  return originalLink(tokens, index, options, environment, self)
}

export function renderMarkdown(markdown: string, directory = ''): string {
  const raw = md.render(splitFrontMatter(markdown).body, { directory })
  const sanitized = DOMPurify.sanitize(raw, {
    ADD_TAGS: ['math', 'semantics', 'annotation'], ADD_ATTR: ['xmlns', 'encoding'],
    ALLOW_UNKNOWN_PROTOCOLS: false,
    ALLOWED_URI_REGEXP: /^(?:(?:https?|mailto|mori-asset):|data:image\/(?:png|jpeg|gif|webp);|[^a-z]|[a-z+.-]+(?:[^a-z+.-:]|$))/i,
    FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'style', 'form'], FORBID_ATTR: ['srcset', 'onerror']
  })
  const template = document.createElement('template'); template.innerHTML = sanitized
  const seen = new Map<string, number>()
  for (const heading of template.content.querySelectorAll('h1,h2,h3,h4,h5,h6')) {
    if (!heading.id) heading.id = headingID(heading.textContent ?? '', seen)
  }
  for (const element of template.content.querySelectorAll<HTMLElement>('[style]')) {
    if (!element.closest('.katex')) { element.removeAttribute('style'); continue }
    const allowed = new Set(['height', 'width', 'min-width', 'top', 'vertical-align', 'margin-left', 'margin-right', 'padding-left', 'padding-right', 'border-bottom-width'])
    for (const property of Array.from({ length: element.style.length }, (_, index) => element.style.item(index))) {
      if (!allowed.has(property) || !/^[-+\d.\s]+(?:em|px|%)?$/.test(element.style.getPropertyValue(property))) element.style.removeProperty(property)
    }
  }
  return template.innerHTML
}

let diagramSequence = 0
export async function renderDiagrams(container: HTMLElement, dark: boolean): Promise<void> {
  mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: dark ? 'dark' : 'neutral', suppressErrorRendering: true })
  const blocks = [...container.querySelectorAll<HTMLElement>('code.language-mermaid')]
  await Promise.all(blocks.map(async code => {
    const source = code.textContent ?? ''
    const preview = document.createElement('div'); preview.className = 'mermaid-output'
    try {
      const { svg } = await mermaid.render(`mori-diagram-${++diagramSequence}`, source)
      preview.innerHTML = DOMPurify.sanitize(svg, { USE_PROFILES: { svg: true, svgFilters: true } })
      if (container.contains(code)) code.closest('pre')?.replaceWith(preview)
    } catch { code.closest('pre')?.setAttribute('aria-label', '图表语法尚未完成') }
  }))
}

export async function renderDiagram(source: string, target: HTMLElement): Promise<void> {
  const sequence = String(++diagramSequence); target.dataset.generation = sequence
  try {
    mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: document.documentElement.dataset.theme === 'night' ? 'dark' : 'neutral', suppressErrorRendering: true })
    const { svg } = await mermaid.render(`mori-block-${sequence}`, source)
    if (target.dataset.generation === sequence) target.innerHTML = DOMPurify.sanitize(svg, { USE_PROFILES: { svg: true, svgFilters: true } })
  } catch { if (target.dataset.generation === sequence) target.textContent = '图表语法尚未完成，继续编辑代码。' }
}
