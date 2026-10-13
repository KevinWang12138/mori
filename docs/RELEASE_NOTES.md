Mori 0.1.2 修复背景设置和编辑输入的问题，并把首次启动语言设为英文。

- 背景预览不再拦截鼠标，主题卡片、图片选择和背景滑块可以正常点击；卡片的空白区域也能切换主题。
- 切换外观、文字和偏好设置时回到顶部；主题导入失败会直接显示在设置窗口上方。
- 新建博客文章后，直接输入从正文开始；写作、源码和分栏模式切换后，输入进入当前编辑器。
- 查找替换保留输入的大小写，关闭自动更正。
- 修复 PDF 导出卡住、持续生成页面的问题；HTML 导出补齐文章样式和离线公式字体。
- 默认 English，可切换简体中文或主动选择跟随系统；已有语言选择继续保留。

已手动点击检查背景、编辑、保存、元信息、查找替换、导出和语言切换。检查范围与结果见 [手动检查记录](https://github.com/KevinWang12138/mori/blob/main/docs/MANUAL_QA.md)。

Mori 0.1.2 fixes unresponsive appearance controls, cursor placement in new articles and editor mode switches, exact-text replacement, PDF pagination, and missing styles in HTML exports. The initial interface is now English; Simplified Chinese and Follow System remain available, and existing language choices are remembered.

适用于 macOS 14+。ZIP 和 DMG 均包含 Apple Silicon / Intel 通用应用，校验见 SHA256SUMS.txt。此版本使用 ad-hoc 签名，尚未使用 Apple Developer ID 公证；首次打开步骤见 README。无需 Apple 商店或本地服务。
