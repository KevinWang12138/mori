import { readFile, writeFile, readdir } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root = fileURLToPath(new URL('../', import.meta.url))
const lock = JSON.parse(await readFile(path.join(root, 'Web/package-lock.json'), 'utf8'))
const entries = []
const texts = new Map()
for (const [location, entry] of Object.entries(lock.packages)) {
  if (!location || entry.dev) continue
  const directory = path.join(root, 'Web', location)
  const pkg = JSON.parse(await readFile(path.join(directory, 'package.json'), 'utf8'))
  entries.push(`| ${pkg.name} | ${pkg.version} | ${pkg.license ?? entry.license ?? '见包内许可'} |`)
  const names = await readdir(directory)
  for (const name of names.filter(name => /^(license|licence|copying)(?:$|[.-])/i.test(name))) {
    let content
    try { content = await readFile(path.join(directory, name), 'utf8') } catch { continue }
    content = content.replaceAll('\r\n', '\n').split('\n').map(line => line.trimEnd()).join('\n').trim()
    if (!content) continue
    const hash = createHash('sha256').update(content).digest('hex')
    const existing = texts.get(hash)
    if (existing) existing.packages.push(pkg.name)
    else texts.set(hash, { packages: [pkg.name], content })
  }
}
const sections = [...texts.values()].map(({ packages, content }) => `### ${packages.join(', ')}\n\n\`\`\`text\n${content.trim()}\n\`\`\`\n`)
await writeFile(path.join(root, 'THIRD_PARTY_NOTICES.md'), '# 第三方许可\n\nMori 使用下列开源运行依赖。版本取自 lockfile；本文件收录包内许可原文。开发工具不包含在应用运行时。\n\n应用所带 `editor.js.LEGAL.txt` 同时包含打包代码的许可标记。KaTeX 字体的许可随 katex 包许可一起收录。\n\n## 运行依赖\n\n| 包 | 版本 | 许可 |\n| --- | --- | --- |\n' + entries.sort().join('\n') + '\n\n## 许可原文\n\n' + sections.join('\n'))
console.log(`已整理 ${entries.length} 项运行依赖许可。`)
