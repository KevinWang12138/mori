enum WelcomeArticle {
    static var content: String { L10n.language == .english ? english : chinese }
    private static let chinese = """
    ---
    title: "给写作留一片安静的地方"
    description: "从一个想法开始，写成一篇属于你的文章。"
    tags: [写作, Mori]
    draft: true
    ---

    # 给写作留一片安静的地方

    慢一点，把想法写下来。

    这是你的第一张写作纸。Mori 把工具藏在恰好的位置，让注意力留给文字。你可以直接在这篇文章里编辑，也可以打开自己的博客文件夹。

    ## 从一行文字开始

    输入 `#` 加空格写一个标题，用 `-` 加空格列出想法，用 `>` 加空格留下一句引用。选中文字后，格式工具会出现在手边。

    > 写作，是把散落的想法慢慢收拢。

    **⌘N** 新建文章，**⌘O** 打开文件，**⌘S** 保存。输入 `/` 打开插入菜单。

    ## 一篇博客需要的东西

    - [x] 不打断思路的所见即所得编辑
    - [x] 标题、列表、链接、图片和表格
    - [x] 为 Astro、Hugo 和 Jekyll 准备的文章模板
    - [ ] 写下今天的第一个想法

    | 习惯 | 留给自己的时间 |
    | --- | --- |
    | 写一点 | 每天 20 分钟 |
    | 整理一下 | 每周一次 |
    | 发布一篇 | 准备好了就发布 |

    ## 让这里像你自己的书桌

    点击右上角的外观按钮，选择林间晨雾，或放进自己喜欢的照片。图片可以铺满、完整显示或平铺；位置、缩放、模糊、色彩和纸面透明度都能调整。

    在 **Mori → 语言** 或 **写作环境 → 偏好** 中切换中文与 English。

    需要安静的时候，用 **⌘⇧F** 进入专注模式。用 **⌘⇧T** 打开打字机模式，让当前段落停在视线中央。

    ```swift
    let thought = "把想法写下来"
    print(thought)
    ```

    ---

    文章属于你，Markdown 文件也属于你。Mori 离线工作，草稿保留在本机，已保存的文件会自动保存后续修改。
    """
    private static let english = """
    ---
    title: "A quiet place for your words"
    description: "Start with a thought. Let it become your next blog post."
    tags: [writing, Mori]
    draft: true
    ---

    # A quiet place for your words

    Slow down. Put your thoughts into words.

    This is your first page in Mori. Your article takes the center; the tools stay within reach. Edit this page, start a new draft, or open your blog folder.

    ## Begin with one line

    Type `#` followed by a space for a heading, `-` for a list, or `>` for a quote. Select text to reveal the formatting tools.

    > Writing gives scattered thoughts a place to belong.

    **⌘N** creates an article, **⌘O** opens a file, and **⌘S** saves it. Type `/` to open the insert menu.

    ## Everything a blog post needs

    - [x] Live Markdown editing that keeps you in the flow
    - [x] Headings, lists, links, images, and tables
    - [x] Article templates for Astro, Hugo, and Jekyll
    - [ ] Write down your first thought for today

    | A small habit | Time to make it yours |
    | --- | --- |
    | Write a little | Twenty minutes a day |
    | Gather your ideas | Once a week |
    | Publish a post | When it is ready |

    ## Make this feel like your desk

    Open the writing environment button at the top right. Choose Forest Mist or bring your own photo. Adjust image fit, position, scale, blur, color, and page opacity.

    Use **⌘⇧F** for focus mode and **⌘⇧T** for typewriter mode. Choose **Mori → Language** or **Writing Environment → Preferences** to switch between English and 简体中文.

    ```swift
    let thought = "Put your thoughts into words"
    print(thought)
    ```

    ---

    Your articles and Markdown files belong to you. Mori works offline, keeps drafts on your Mac, and automatically saves changes to named files.
    """
}
