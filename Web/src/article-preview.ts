interface PreviewContent { markdown: string; directory: string; dark: boolean }

export class ArticlePreview {
  private timer?: ReturnType<typeof setTimeout>
  private generation = 0

  constructor(private readonly render: (content: PreviewContent) => Promise<HTMLElement>,
    private readonly commit: (article: HTMLElement) => void, private readonly onError: () => void) {}

  // ===== 输入时立即作废旧渲染，避免防抖等待期间旧预览覆盖新内容 =====
  schedule(content: PreviewContent): void {
    this.cancel()
    const generation = this.generation
    const snapshot = { ...content }
    this.timer = setTimeout(() => {
      this.timer = undefined
      void this.update(snapshot, generation)
    }, 120)
  }

  // ===== 切换文章、退出分栏或关闭标签后禁止异步结果写回 =====
  cancel(): void {
    this.generation++
    if (this.timer) clearTimeout(this.timer)
    this.timer = undefined
  }

  private async update(content: PreviewContent, generation: number): Promise<void> {
    try {
      const article = await this.render(content)
      if (generation === this.generation) this.commit(article)
    } catch {
      if (generation === this.generation) this.onError()
    }
  }
}
