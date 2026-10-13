<p align="center"><strong>English</strong> · <a href="README.zh-CN.md">简体中文</a></p>
<p align="center"><img src="assets/AppIcon.png" width="110" alt="Mori icon"></p>
<h1 align="center">Mori</h1>
<p align="center">A quiet place to write your next blog post.</p>
<p align="center">Native macOS · Markdown · English / 简体中文 · Offline writing · MIT licensed</p>
<p align="center"><a href="https://github.com/KevinWang12138/mori/releases/latest">Download for Mac</a> · <a href="docs/USER_GUIDE.md">User guide (中文)</a> · <a href="https://github.com/KevinWang12138/mori/issues">Report an issue</a></p>

Mori is a native Mac Markdown editor built for blog writers. Write directly in your document: Markdown shortcuts turn into headings, lists, and quotes as you type. Switch to source editing or a split preview whenever you need it. Inspired by Typora's direct editing experience, Mori has its own implementation, visual design, and identity.

![Mori live Markdown editor with the article library, outline, and forest wallpaper](docs/screenshots/writing-en.jpg)

*Live editing with your article library, outline, and a writing space you can make your own. Screenshots show the actual macOS app with public example articles.*

## Writing

- Three modes: live editing, Markdown source, and source with a side-by-side preview.
- Headings, bold, italic, strikethrough, inline code, links, quotes, nested lists, and task lists.
- Editable tables with row and column operations and column resizing; syntax highlighting and language selection for code blocks.
- KaTeX equations and Mermaid diagrams. The source preview also supports footnotes and sanitized HTML.
- Selection formatting tools, a `/` insert menu, find and replace, undo, and redo.
- Import, paste, or drag images into your article. Images live in an `assets/` folder beside the Markdown file and use relative paths.
- An article library with recursive folder indexing, filename search, optional content search, outline navigation, and document tabs.
- Mixed Chinese and English word counts, estimated reading time, writing goals, focus mode, and typewriter mode.

## Blogging and files

- Four starting templates: blank, Astro, Hugo, and Jekyll.
- A Front Matter panel for titles, descriptions, dates, slugs, tags, categories, cover images, and draft status. It updates only the fields you change and preserves other YAML fields and comments.
- Autosave, session restoration, and recovery for unnamed drafts. External file changes are checked before saving to protect your current work.
- Preserve existing UTF-8 BOMs and CRLF line endings. Keep the latest 50 local revisions of each article.
- Export standalone HTML and PDF, use the system print dialog, or copy HTML and Markdown. HTML exports embed local images and equation fonts.

## Make your writing space your own

Choose from three base themes: Paper, Sage, and Night. Use the built-in forest wallpaper or bring your own photos and textures.

| Setting | Controls |
| --- | --- |
| Image placement | Fill, fit, or tile |
| Composition | Zoom and horizontal or vertical position |
| Image treatment | Opacity, blur, and saturation |
| Readability | Background color, overlay color, and overlay opacity |
| Writing surface | Separate opacity controls for the page and sidebar |
| Typography | Three font options, font size, line spacing, and page width |
| Extensions | Custom article CSS and JSON theme import/export |

Custom backgrounds are copied into Mori's application data folder, so moving the original photo will not remove your background. Exported themes contain settings and CSS; private background images stay on your Mac. Share an image separately and import it on another Mac when needed.

![Mori background controls with theme choices, image placement, opacity, and a live preview](docs/screenshots/appearance-en.jpg)

## Language

Choose **Mori → Language**, or open **Writing Environment (⌘,) → Preferences → Interface language**. Select **Follow System**, **English**, or **简体中文**. The default follows your primary system language and uses English for unsupported languages.

Your choice is remembered and applies immediately to the interface, editor tools, and prompts. Articles, Front Matter, cursor positions, undo history, and appearance settings are preserved. Language preferences stay separate from imported and exported themes.

![Mori preferences in Simplified Chinese with the interface language selector](docs/screenshots/language-zh-CN.jpg)

## Download and install

Requires **macOS 14 or later**. Releases include a universal app for Apple Silicon and Intel Macs.

1. Download the DMG or ZIP from [Releases](https://github.com/KevinWang12138/mori/releases/latest).
2. Open the DMG and drag Mori into Applications. For the ZIP, extract it and move Mori.app into Applications.
3. Open Mori and choose an article or your blog folder.

### First launch on macOS

Version 0.1.1 uses ad-hoc signing and has not been notarized with Apple Developer ID. If macOS displays “Mori Not Opened” when you first launch it:

1. Select **Done** to keep the app installed.
2. Open **System Settings → Privacy & Security**.
3. Find the message about Mori, select **Open Anyway**, and confirm **Open**.

See [Apple's instructions for opening an unnotarized app](https://support.apple.com/en-us/102445). The release includes `SHA256SUMS.txt` to verify the downloaded DMG or ZIP.

For a copy you have verified came from this repository, you can also remove the quarantine attribute from that specific installed app in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Mori.app
open /Applications/Mori.app
```

## Build locally

Requires Xcode 15+, Swift 5.9+, Node.js 20+, and npm. Open `Package.swift` to edit the project in Xcode; use the build script to package the app.

```bash
git clone https://github.com/KevinWang12138/mori.git
cd mori
cd Web && npm ci && cd ..
./scripts/build-app.sh
open build/Mori.app
```

The script builds a universal app by default. On Apple Silicon, set `MORI_UNIVERSAL=0` to build only the ARM version. Editor dependencies and fonts are bundled with the app, so running Mori requires neither Node.js nor a local server.

Run the checks:

```bash
./scripts/check.sh
```

Project structure:

```text
Sources/Mori/      SwiftUI views, AppKit file and window integration, WebKit bridge
Sources/MoriCore/  File writes, conflict checks, Markdown analysis, recovery and history
Web/src/          Tiptap live editing, CodeMirror source editing, Markdown preview
Tests/            File safety and article analysis tests
Web/tests/        Markdown round-trip, metadata, and preview tests
scripts/          Checks, app packaging, and releases from an exact commit SHA
```

## Current limitations

- Extended syntax such as footnotes, reference links, MDX, embedded HTML, directive blocks, and `[TOC]` automatically uses source mode to preserve the original text. Split mode previews supported content. MDX components are not executed.
- Editing standard Markdown in live mode normalizes syntax and blank lines. Opening a file or switching modes alone does not write it back to disk.
- Articles must be UTF-8 and no larger than 20 MB; images are limited to 25 MB. Content search indexes articles smaller than 2 MB. Open a result from the sidebar, then use the editor's search to find text within that article.
- Live editing supports search across inline formatting, previous/next matches, case sensitivity, and individual or bulk replacement. Source mode also supports regular expressions and whole-word matching.
- There are no cloud accounts, blog publishing APIs, or built-in sync. Keep your Markdown folder in your own Git, iCloud, or other sync directory.
- HTTPS images explicitly referenced in an article are requested from their source. Links open in the system browser when you click them. Mori sends no telemetry and does not upload your writing.
- Mori supports English and Simplified Chinese interfaces. macOS system dialogs follow your macOS language. This repository provides English and Chinese READMEs.

## Open source

Released under the [MIT License](LICENSE). Issues and contributions are welcome. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for dependency licenses and [SECURITY.md](SECURITY.md) for security information. Mori is not affiliated with Typora.
