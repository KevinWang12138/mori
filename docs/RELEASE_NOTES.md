Mori 0.1.4 优化长文编辑与文章库，并修复快速切换和异步操作中的内容错位。

- 定时文件检查与文章库扫描移到后台；重复扫描可以取消，保存后不会被过期检查结果回退。正文搜索优先使用已打开文章的最新内容，并在读取索引前检查文件大小。
- 字数、大纲和标签标题复用解析结果；只在编辑器状态变化时同步内容与设置。调整字体和主题不再重复重配源码插件，文章库按需创建列表行。
- 分栏预览在新输入、切换模式或关闭标签时立即作废旧渲染，避免耗时图表覆盖更新的内容。
- 复制、导出与元信息读取固定到目标文章；导出期间切换标签不改变本地图片的读取范围。图片首次加载使用所属文章目录，另存文件保留编辑器的撤销记录。
- 源码列表转换不再残留复选框标记，选区恰好停在下一行开头时不会误改该行。插入图片会处理描述与路径中的特殊字符。
- HTML 注释、闭合标签等扩展内容使用源码模式保留；正确识别更长的闭合代码围栏，继续检查围栏后面的正文语法。

自动化检查覆盖文件冲突、后台结果过期与取消、预览时序、文章切换、图片目录、导出内容和源码转换；保留 1200 段长文拖选与复制回归。本次未进行手动界面验证。

Mori 0.1.4 reduces repeated work during long-document editing and moves file checks and library scans off the main thread. It prevents stale previews and file-check results from replacing newer content, keeps copy/export operations tied to the intended article, and preserves image paths and undo history when files move. Source formatting and unsupported Markdown preservation also receive regression fixes. Automated checks cover these changes and the existing long-document selection behavior; the application UI has not been manually checked for this release.

适用于 macOS 14+。ZIP 和 DMG 均包含 Apple Silicon / Intel 通用应用，校验见 SHA256SUMS.txt。此版本使用 ad-hoc 签名，尚未使用 Apple Developer ID 公证；首次打开步骤见 README。无需 Apple 商店或本地服务。
