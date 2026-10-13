# README 应用截图

这些图片来自 Mori 0.1.1 的实际 macOS 窗口。仅使用本目录的公开示例文章和内置森林背景；不包含个人文章或用户设置。

- `writing-en.jpg`：英文直接写作、文章库与大纲。
- `appearance-en.jpg`：背景图片、构图和纸面控制。
- `language-zh-CN.jpg`：简体中文界面与语言选择器。

重新截图时先运行 `scripts/build-app.sh`，再运行 `python3 scripts/prepare-screenshots.py`。脚本创建资料与设置独立的 Mori Documentation 实例，并输出应用路径。使用原生应用截图工具获取窗口，按截图工具返回的真实图片格式保存；不要以生成图替代真实界面。

截图完成后运行 `python3 scripts/prepare-screenshots.py --cleanup`，退出该实例并清理临时文章、应用副本与设置。不会停止或覆盖正常安装的 Mori。
