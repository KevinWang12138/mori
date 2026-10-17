Mori 0.1.3 修复复制前拖选文字卡顿、选区被自动滚动干扰的问题。

- 拖选期间暂停悬浮工具栏的位置计算，松开鼠标后再显示格式工具，避免浮层遮挡正在选择的文字。
- 打字机模式只跟随折叠的输入光标，鼠标拖选、点击定位和键盘扩选不再触发自动居中；写作、源码和分栏模式均适用。
- 标题锚点与代码高亮复用缓存，纯选区变化不再扫描全文；专注段落高亮由编辑器装饰维护，避免逐段修改 DOM。
- 合并同一帧中的选区更新，保留跨段复制、格式工具、斜杠菜单、标题锚点和代码高亮的行为。

新增回归覆盖 1200 段长文章、正反向拖选、跨段复制、键盘扩选、源码与分栏模式，以及编辑后的锚点和代码高亮更新。本次采用自动化回归与构建检查，未进行手动界面验证。

Mori 0.1.3 improves text selection before copying. Formatting tools wait until dragging ends, and typewriter scrolling respects mouse selections and keyboard selection ranges in all editing modes. Heading anchors and code highlighting reuse cached decorations during selection changes. Automated regressions cover long documents, forward and backward selections, cross-paragraph copying, and editor tools; this release has not been manually checked in the application UI.

适用于 macOS 14+。ZIP 和 DMG 均包含 Apple Silicon / Intel 通用应用，校验见 SHA256SUMS.txt。此版本使用 ad-hoc 签名，尚未使用 Apple Developer ID 公证；首次打开步骤见 README。无需 Apple 商店或本地服务。
