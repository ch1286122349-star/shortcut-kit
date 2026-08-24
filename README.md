# ShortcutKit

一个可在 GitHub 直接下载的开源 macOS 快捷键管理器。菜单栏 App 会列出每个快捷键，支持逐项开关、直接录入新组合、冲突检查和恢复默认；Hammerspoon 作为后台运行引擎。安装器不会绕过 macOS 权限，也不会覆盖未备份的配置。

## 最简单的安装方式

1. 从 [GitHub Releases](https://github.com/ch1286122349-star/shortcut-kit/releases/tag/v0.2.0) 下载 `ShortcutKit-v0.2.0.dmg`。
2. 打开 DMG，把 `ShortcutKit.app` 拖入“应用程序”。
3. 首次打开如果出现开发者警告，在 Finder 中右键 App 选择“打开”，或到“系统设置 → 隐私与安全性”允许打开。
4. 在 ShortcutKit 的“权限与依赖”页点击“安装或修复”。它会安装 App 携带的 ShortcutKit；电脑没有 Hammerspoon 时也会一并安装。
5. 按 macOS 提示，手动给 Hammerspoon开启“辅助功能”和“屏幕录制”。

v0.2.0 是未签名、未公证的 GitHub 开源版本，不经过 Mac App Store。请只从本仓库 Release 下载，并核对随附的 SHA-256 文件。

### 通过源码安装或恢复

```bash
git clone https://github.com/ch1286122349-star/shortcut-kit.git
cd shortcut-kit
./install.sh --dry-run
./install.sh --apply
```

也可以在 Finder 双击 `安装.command`。如果电脑尚未安装 Hammerspoon，脚本会优先使用 Homebrew Cask；没有 Homebrew 时下载固定版本的官方 ZIP并校验 SHA-256，不会自动安装 Homebrew。

首次使用时，macOS 会要求你手动授予 Hammerspoon“辅助功能”和“屏幕录制”权限。ShortcutKit 无法也不会自动授予这些权限。

## App 里能做什么

- 菜单栏快速打开设置、开启/关闭全部快捷键、查看运行状态。
- 每个模块单独勾选开启或关闭；依赖缺失只影响对应模块。
- 点击普通快捷键的按键框，直接按下新组合即可替换默认值。例如窗口截图不必使用 `⌘ R`，可以改成 `⌃ ⇧ 5`。
- 保存前检查 ShortcutKit 内部重复、Hammerspoon 已占用组合和 macOS 可报告的系统快捷键。
- 单项“恢复默认”或“全部恢复默认按键”；不会改变各模块开关。
- 用户自定义组合写入 `~/Library/Application Support/ShortcutKit/config.json`，更新 App 或 Spoon 时保留。
- 长按右 Option、左键+C/V/D 等特殊手势在本版可开关；手势内部规则暂不开放编辑。

## 默认快捷键

下面只是出厂预设，不是写死的按键：

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

推荐直接在 App 中录入。高级用户仍可参考 [`config.example.lua`](config.example.lua) 调整应用候选 Bundle ID；App 管理的模块开关和快捷键覆盖保存在 JSON 配置中。更新只替换程序文件，不清除用户选择。

## 常见问题

- **按键没反应：** 打开 Hammerspoon Console，运行 `shortcutKitStatus()`；确认辅助功能权限和对应应用是否被检测到。
- **截图/OCR 无结果：** 确认 Hammerspoon 有屏幕录制权限；OCR 取消框选不会产生错误提示。
- **快捷键冲突：** App 会阻止已确认的内部、Hammerspoon 或系统冲突，并显示来源；BetterTouchTool、Karabiner 等无法完整自动读取的第三方来源仍需手动检查。
- **安装被开发者警告拦住：** 本项目不经过 App Store；请只从你信任的仓库和 Release 校验包安装。
- **想完整回退：** 先运行 `./restore.sh --dry-run` 查看目标，再运行 `--apply`。

English documentation: [README.en.md](README.en.md)
