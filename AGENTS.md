# Mori 项目协作规则

Mori 是原生 macOS 博客 Markdown 编辑器。SwiftUI/AppKit 负责窗口、文件和系统集成，内置 WebKit 承载离线所见即所得编辑器。

- 遵循 `/Users/kevin/.codex/AGENTS.md` 和工作区顶层规则；只在 main 上提交、推送。
- macOS 14+；Swift Package Manager 构建，Web 编辑器采用 TypeScript、Tiptap 和 CodeMirror。npm 管理 Web 依赖，锁定版本。
- View 只做界面组合；文件保存、冲突检查、会话恢复、资源导入、导出分别放入语义明确的服务或协调器。中文注释使用 `// ===== ... =====` 标记。
- 用户内容只保存在本机；不引入账户、遥测、云端 API 或隐式上传。
- 未识别的 Markdown 必须原样保留。模式切换不得自动写回或清除内容；所见即所得编辑有无法无损处理的语法时使用源码模式。
- WebKit 是应用内部编辑器组件，不用于浏览网页或进行浏览器验证。禁止主动启动浏览器、curl 页面、路由扫描或视觉审查。
- 必要检查：`swift test`、`swift build -c release`、Web `npm run check`、`npm test`、`git diff --check`。无需启动本地服务。
- 发布目标：公开 GitHub 仓库 `KevinWang12138/mori`，GitHub Releases 分发 macOS universal 应用 ZIP 与 DMG。无服务器部署目标。
- 发布：在 main 提交并推送后，`scripts/release.sh <版本> <完整SHA>` 从已提交源码构建 universal 应用，生成 SHA256 校验文件，通过 `gh release create` 上传；`gh release view` 和 release assets 元数据核对版本、tag SHA、文件大小与 digest。
- 无 Developer ID 凭证时只使用 ad-hoc 签名，明确说明未公证；不得宣称 App Store 或公证发布。签名凭证存在时使用 `MORI_SIGN_IDENTITY`、`MORI_NOTARY_PROFILE` 走签名、公证流程。
- 发布后写入 `~/.codex/deployments/mori.json`。已核对上传的临时发布目录及时清理；保留 `build/Mori.app` 供 Kevin 使用。
