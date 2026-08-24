# ShortcutKit

把一套经过实机验证的 macOS 快捷键打包成可审计、可更新、可卸载、可恢复的开源 Hammerspoon 配置。安装器不会替你绕过 macOS 权限，也不会覆盖未备份的配置。

## 30 秒安装

```bash
git clone https://github.com/YOUR_GITHUB_USER/shortcut-kit.git
cd shortcut-kit
./install.sh --dry-run
./install.sh --apply
```

也可以在 Finder 双击 `安装.command`。如果电脑尚未安装 Hammerspoon，脚本会优先使用 Homebrew Cask；没有 Homebrew 时下载固定版本的官方 ZIP 并校验 SHA-256，不会自动安装 Homebrew。

首次使用时，macOS 会要求你手动授予 Hammerspoon“辅助功能”和“屏幕录制”权限。ShortcutKit 无法也不会自动授予这些权限。

## 快捷键

| 快捷键 | 作用 | 生效范围 |
|---|---|---|
| `⌘ R` | 截取鼠标所在窗口并复制到剪贴板 | 全局 |
| `⌘ S` | 框选屏幕，本地 Vision OCR，文字写入剪贴板 | 全局 |
| `⌘ Space` | 发送原生 `⌘ O` | 全局 |
| 长按右 `Option` 0.35 秒后松开 | 连续输入三个空格 | 全局；作为组合键时不触发 |
| 按住鼠标左键 0.05 秒 + `C` / `V` | 复制 / 粘贴 | 全局；鼠标点击和拖拽保持透传 |
| 按住鼠标左键 0.05 秒 + `D` | 删除；Finder 中为移到废纸篓 | 全局 |
| `⌘ 3` | 切换到当前 Chrome 窗口的上一个标签 | 仅 Chrome |
| `⌘ ⇧ 2` / `⌘ ⇧ 3` | 在 Codex 输入空格、`@chrome`，等待候选后按 Tab | Codex 已安装时 |
| `⌘ 2` | 显示/隐藏 Codex，并返回此前窗口 | Codex 已安装时 |
| `⌘ 5` / `⌘ 小键盘5` | 显示/隐藏网易邮箱大师并修复主窗口焦点 | 邮箱大师已安装时 |
| `⌘ \`` / `⌘ §` | 显示/隐藏 ChatGPT Classic 主窗口 | ChatGPT Classic 已安装时 |
| `⌃ ⌥ 1` / `2` / `3` / `4` | Classic 的 Auto / Instant / Thinking / Pro 模型 | 仅 ChatGPT Classic 前台 |
| `⌘ W` | 隐藏并保留 WhatsApp Edge PWA 窗口 | 仅精确匹配的 WhatsApp PWA；其他 App 保持原生行为 |

BetterTouchTool 运行且变量 API 可读时，会自动启用截图释放桥接；未安装 BTT 不影响其他快捷键。

## 安全和兼容策略

- 每个应用模块会按 Bundle ID 自动检测。依赖缺失时只跳过该模块，其他快捷键继续运行。
- 同一个组合键被重复声明时，该模块会报告冲突并停止，不会静默覆盖。
- OCR 完全在本机使用 Apple Vision 运行，不上传截图。
- 安装前会备份现有 `init.lua` 和旧版 ShortcutKit；重复安装只保留一个加载块。
- 鼠标事件始终透传，普通点击、拖拽和 macOS 三指拖移不应被接管。

## 更新、卸载与恢复

```bash
./update.sh --apply --skip-hammerspoon
./uninstall.sh --dry-run
./uninstall.sh --apply
./restore.sh --apply
```

对应的 `更新.command`、`卸载.command`、`恢复.command` 可以直接双击。卸载只移除 ShortcutKit 的标记加载块和 Spoon，不卸载 Hammerspoon。恢复使用最近一次自动备份。

## 自定义

参考 [`config.example.lua`](config.example.lua)，把需要覆盖的表传给 `spoon.ShortcutKit:start({...})`。应用候选 Bundle ID、模块开关和快捷键都可以调整。

## 常见问题

- **按键没反应：** 打开 Hammerspoon Console，运行 `shortcutKitStatus()`；确认辅助功能权限和对应应用是否被检测到。
- **截图/OCR 无结果：** 确认 Hammerspoon 有屏幕录制权限；OCR 取消框选不会产生错误提示。
- **快捷键冲突：** 检查 macOS 系统快捷键、Hammerspoon、BetterTouchTool、Karabiner 等来源，再修改 `hotkeys` 覆盖项。
- **安装被开发者警告拦住：** 本项目不经过 App Store；请只从你信任的仓库和 Release 校验包安装。
- **想完整回退：** 先运行 `./restore.sh --dry-run` 查看目标，再运行 `--apply`。

English documentation: [README.en.md](README.en.md)
