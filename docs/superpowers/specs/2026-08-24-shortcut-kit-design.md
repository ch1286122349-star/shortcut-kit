# ShortcutKit 设计规格

- 日期：2026-08-24
- 状态：用户已确认
- 默认仓库名：`shortcut-kit`
- 发布方式：公开 GitHub 仓库
- 许可证：MIT
- 首发平台：macOS 13 及以上

## 1. 目标

ShortcutKit 是一套可公开、可审计、可一键安装的 macOS 快捷键配置。第一版迁移当前机器上所有实际启用的 Hammerspoon 快捷键和相关后台行为，同时避免公开私人路径、账号、日志与机器专用状态。

用户可从 GitHub 克隆仓库或下载 ZIP，然后双击 `安装.command`。安装器负责安装或复用 Hammerspoon、备份原配置、检测依赖与冲突、安装模块、重载配置并输出验证报告。项目同时提供更新、卸载和恢复入口。

第一版成功标准：

1. 在当前机器完成从单文件配置到 ShortcutKit 模块的真实迁移，所有当前启用行为保持一致。
2. 连续三次触发每个关键快捷键均成功；涉及 App 的功能在对应 App 存在时通过真实场景验证。
3. 在一份空白临时用户配置和一份已有个人配置的测试夹具中完成安装、更新、卸载和恢复测试。
4. 公开仓库不包含 token、密码、API Key、私人日志、对话内容、浏览历史或用户目录绝对路径。
5. GitHub 仓库包含中文主文档、英文简版文档、MIT License、安装脚本、测试和故障排查说明。

## 2. 范围

### 2.1 第一版包含

#### 核心通用模块

- `Command+R`：截取鼠标所在最上层可见窗口，直接写入剪贴板。
- `Command+S`：框选屏幕区域，使用本地 macOS Vision OCR 识别中简、中繁、英文和西语，写入剪贴板。
- `Command+Space`：发送 `Command+O`。
- 长按右 Option：发送三次空格；作为其他组合键使用时不触发。
- 按住鼠标左键后按 `C`：发送 `Command+C`。
- 按住鼠标左键后按 `V`：发送 `Command+V`。
- 按住鼠标左键后按 `D`：Finder 中发送 `Command+Delete`，其他 App 中发送普通 Delete。
- 鼠标按下、拖动、三指拖动和鼠标抬起事件保持透传。

#### App 条件模块

- Codex：`Command+2` 打开/隐藏 Codex，并恢复切换前的窗口。
- Chrome：`Command+3` 在当前 Chrome 窗口的最近两个仍存活标签页之间切换。
- Codex 输入框：`Command+Shift+2` 与 `Command+Shift+3` 执行两套现有 `@chrome` 输入时序。
- 网易邮箱大师：`Command+5` 和数字键盘 `Command+5` 打开/隐藏主窗口，并修复错误焦点。
- ChatGPT Classic：`Command+反引号` 和 `Command+§` 打开/隐藏主窗口，并保留当前失焦自动隐藏行为。
- ChatGPT Classic：`Control+Option+1/2/3/4` 切换 Auto、Instant、Thinking、Pro 模型。
- WhatsApp Edge Web App：`Command+W` 隐藏应用但保留窗口。
- BTT 协调模块：仅在 BetterTouchTool 存在且检测到对应变量时启用截图释放状态桥。

#### 运维入口

- `安装.command` / `install.sh`
- `更新.command` / `update.sh`
- `卸载.command` / `uninstall.sh`
- `恢复.command` / `restore.sh`
- 安装结果报告与运行状态检查命令

### 2.2 第一版不包含

- BetterTouchTool 数据库中的 108 条独立触发器迁移。
- Karabiner-Elements 配置迁移。
- macOS 系统快捷键偏好迁移。
- 云同步、账号系统、遥测、自动上传日志。
- App Store、Apple Developer 签名或公证。
- Windows 或 Linux 支持。
- 自动授予辅助功能、屏幕录制等 macOS 隐私权限。

## 3. 设计原则

1. **不覆盖用户配置**：陌生机器只插入带边界标记的加载块。
2. **可回滚**：任何写入前先备份；失败时自动恢复。
3. **按依赖启用**：通用模块默认启用，App 模块仅在依赖存在时启用。
4. **故障隔离**：单个模块失败不能阻止其他模块加载。
5. **本地优先**：OCR 和配置处理不上传数据。
6. **公开安全**：机器路径、Bundle ID 例外和模型标识进入用户配置层。
7. **可重复执行**：安装、更新和卸载均具备幂等性。
8. **保留原生交互**：鼠标与窗口事件只有目标动作被消费，其余继续传给 macOS。

## 4. 仓库结构

```text
shortcut-kit/
├── 安装.command
├── 更新.command
├── 卸载.command
├── 恢复.command
├── install.sh
├── update.sh
├── uninstall.sh
├── restore.sh
├── ShortcutKit.spoon/
│   ├── init.lua
│   ├── config.lua
│   ├── modules/
│   │   ├── window_screenshot.lua
│   │   ├── local_ocr.lua
│   │   ├── command_space.lua
│   │   ├── right_option.lua
│   │   ├── left_mouse_modifier.lua
│   │   ├── codex_toggle.lua
│   │   ├── chrome_recent_tabs.lua
│   │   ├── chrome_mention.lua
│   │   ├── mailmaster.lua
│   │   ├── chatgpt_classic.lua
│   │   ├── whatsapp_keep_window.lua
│   │   └── btt_bridge.lua
│   ├── lib/
│   │   ├── app_detection.lua
│   │   ├── hotkey_registry.lua
│   │   ├── logger.lua
│   │   └── safe_task.lua
│   └── bin/
│       ├── local-ocr.swift
│       ├── local-ocr-arm64
│       ├── local-ocr-x86_64
│       └── local-ocr-universal
├── config.example.lua
├── scripts/
│   ├── preflight.sh
│   ├── install-hammerspoon.sh
│   ├── backup-config.sh
│   ├── patch-init.sh
│   ├── verify-install.sh
│   └── audit-public-files.sh
├── tests/
│   ├── lua/
│   ├── shell/
│   ├── fixtures/
│   └── manual/
├── README.md
├── README.en.md
├── SECURITY.md
├── CONTRIBUTING.md
├── LICENSE
└── .github/workflows/ci.yml
```

## 5. 模块接口

每个模块暴露统一接口：

- `id`：稳定模块标识。
- `description`：中英文功能说明。
- `detect(context)`：判断依赖是否存在并返回原因。
- `defaultEnabled`：默认启用策略。
- `hotkeys(config)`：声明快捷键，供冲突检查使用。
- `start(context)`：注册快捷键、watcher 或 event tap。
- `stop()`：释放所有注册对象。
- `status()`：返回启用、跳过或错误状态。

顶层 `ShortcutKit.spoon/init.lua` 只负责读取配置、启动模块、汇总状态和隔离错误。模块不能直接修改其他模块的状态。

## 6. 配置模型

公开仓库只包含 `config.example.lua`。安装器在 `~/.hammerspoon/shortcut-kit/config.lua` 创建用户配置，更新时不覆盖。

配置项包括：

- 模块启用开关。
- 每个动作的按键映射。
- App Bundle ID 候选列表。
- 可选 App 路径。
- ChatGPT Classic 模型标识。
- OCR 识别语言。
- 日志级别。

机器专用的 WhatsApp Edge PWA Bundle ID 由安装器扫描 `~/Applications` 与 `/Applications` 后写入本地配置，不进入 Git 历史。

## 7. 安装流程

### 7.1 Hammerspoon 安装

1. 已安装 Hammerspoon：复用现有版本。
2. 未安装且 Homebrew 可用：运行 `brew install --cask hammerspoon`。
3. 未安装且无 Homebrew：从 Hammerspoon 官方 GitHub Release 下载锁定版本，校验 SHA-256 后安装。
4. 安装器不自动安装 Homebrew。

### 7.2 配置写入

1. 执行环境预检并生成计划，不立即写入。
2. 将 `~/.hammerspoon` 中会修改的文件复制到时间戳备份目录。
3. 将 `ShortcutKit.spoon` 原子复制到 `~/.hammerspoon/Spoons/`。
4. 创建或保留本地用户配置。
5. 在 `init.lua` 插入唯一标记块：

   ```lua
   -- shortcut-kit:begin
   hs.loadSpoon("ShortcutKit")
   spoon.ShortcutKit:start()
   -- shortcut-kit:end
   ```

6. 静态检查 Lua 与标记块数量。
7. 重载 Hammerspoon并读取模块状态。
8. 失败时自动恢复本轮备份。

### 7.3 当前机器迁移

当前机器的 `init.lua` 已包含同一批快捷键，不能与模块版并行加载。迁移器仅在源文件哈希和结构签名均匹配已审计快照时执行：

1. 完整备份当前 `init.lua`、OCR 源码/二进制、Recent Tabs 模块与测试。
2. 安装 ShortcutKit 模块和本地配置。
3. 将当前 `init.lua` 替换为最小加载器。
4. 重载并逐项验证。
5. 任一核心测试失败则恢复原始配置并重载。

如果哈希或结构签名不匹配，迁移器停止并输出差异，不猜测删除用户代码。

## 8. 冲突策略

- 安装器先读取 ShortcutKit 声明的目标快捷键。
- 对现有 `init.lua` 做保守静态扫描，对运行中的 Hammerspoon 热键表做动态读取。
- 陌生电脑检测到冲突时，默认保留旧绑定并禁用对应 ShortcutKit 动作。
- 当前机器迁移模式中，已知旧实现视为被迁移对象，不视为冲突。
- 用户可在本地配置中明确选择覆盖或改键。
- 冲突报告必须包含按键、现有来源、ShortcutKit 模块和处理结果。

## 9. OCR 分发

- 源码始终公开。
- GitHub Release 提供 macOS 13+ 的 Apple Silicon 与 Intel 构建；可行时合并为 universal binary。
- 安装器按 CPU 架构选择二进制并校验 SHA-256。
- 如果没有匹配二进制但本机有 Swift 工具链，安装器从源码编译。
- 两种方式都不可用时，只禁用 OCR 模块并给出可执行修复说明。
- OCR 仅读取用户主动框选的临时图片；识别结束后删除临时文件。

## 10. 更新、卸载与恢复

### 更新

- Git 克隆用户运行 `更新.command` 拉取已发布版本。
- ZIP 用户重新下载后运行安装器；安装器识别已有版本并升级。
- 更新 Spoon 和公开默认配置，不覆盖用户配置。
- 更新前创建新备份，验证失败自动回滚。

### 卸载

- 停止 ShortcutKit 模块。
- 移除标记加载块、Spoon 和 ShortcutKit 本地配置。
- 保留 Hammerspoon、其他用户配置和备份。

### 恢复

- 列出可用备份及创建时间。
- 恢复用户选择的备份。
- 校验并重载 Hammerspoon。
- 不自动删除更新后的备份。

## 11. 错误处理与日志

- 安装脚本使用严格模式、显式退出码和临时目录。
- 错误分为：环境错误、权限待处理、依赖缺失、快捷键冲突、配置语法错误、模块运行错误。
- 安装器输出人类可读总结，同时生成无隐私的结构化报告。
- 运行日志默认位于 `~/.hammerspoon/shortcut-kit/logs/`，不进入仓库。
- 默认不记录剪贴板内容、OCR 文本、窗口标题、Chrome URL、聊天内容或用户文件路径。
- `--diagnose` 输出模块状态与必要版本信息，敏感字段自动省略。

## 12. 权限引导

Hammerspoon 首次运行后，用户必须在 macOS 中手动授予辅助功能权限。窗口截图与 OCR 需要屏幕录制权限时，安装器负责打开相应系统设置入口并显示逐步说明，但不尝试绕过系统授权。

安装完成状态必须区分：

- 已安装且已授权。
- 已安装、等待权限。
- 部分模块因依赖缺失而跳过。
- 安装失败且已回滚。

## 13. 测试策略

### 自动测试

- Lua 单元测试：窗口选择、模块检测、配置合并、冲突解析、Recent Tabs 历史、状态隔离。
- Shell 测试：空白安装、已有配置、重复安装、升级、卸载、恢复、失败回滚。
- Fixture 测试：不同 `init.lua`、不同 CPU 架构、缺少 App、冲突绑定、损坏配置。
- 公开安全扫描：密钥模式、用户绝对路径、日志和临时产物。
- CI：Lua 语法、ShellCheck、测试套件、文档链接和打包清单。

### 当前机器真实回归

- 核心：`Command+R` 连续三次截图并确认剪贴板图片计数递增。
- OCR：框选包含中英文/西语的测试图，确认剪贴板识别结果。
- Codex、Chrome、邮箱大师、ChatGPT Classic、WhatsApp：逐项模拟主要打开/隐藏/切换场景。
- 鼠标与右 Option：真实按键/鼠标事件回归，确认原生点击、拖动和三指拖动未被消费。
- 更新、卸载、恢复：在迁移后的真实配置上各执行一次并回读状态。

自动化合成事件不能替代所有 event tap 验收；相关功能使用 System Events 或真实物理操作，并结合 Hammerspoon 日志和目标状态回读。

## 14. GitHub 交付

- 默认仓库名：`shortcut-kit`。
- 可见性：Public。
- 默认分支：`main`。
- 许可证：MIT。
- 首个 tag：`v0.1.0`，仅在当前机器迁移和安装器测试通过后创建。
- README 首页包含功能表、30 秒安装说明、权限说明、卸载方式、兼容性和风险边界。
- GitHub Actions 只执行测试和打包；不收集用户数据。

本机存在多个已登录 GitHub 账号。创建远程仓库前必须按账号路由规则明确目标 owner，不能依据当前活动账号猜测。仓库名和公开状态已由本规格固定，owner 是唯一需要在外部写入前核对的部署参数。

## 15. 发布边界

以下状态分别报告，不混为一谈：

1. 本地源码完成。
2. 自动测试通过。
3. 当前机器迁移完成。
4. 当前机器真实快捷键回归通过。
5. GitHub 仓库已创建并推送。
6. Release/tag 已创建。
7. 第三方空白 Mac 安装验证完成。

第一版目标完成到第 6 项。第 7 项需要另一台 Mac 或独立用户环境，若当前没有可用设备则明确保留为发布后验证项。

## 16. 主要风险与控制

- **现有配置被破坏**：双重识别迁移源、完整备份、失败自动回滚。
- **全局快捷键抢占系统/App 默认行为**：冲突预检、陌生电脑默认不覆盖、本地可改键。
- **App Bundle ID 不一致**：候选列表加本机扫描，找不到则禁用模块。
- **OCR 架构不兼容**：分架构构建、校验、源码编译回退。
- **ChatGPT Classic 内部偏好变化**：模块检测偏好结构，不满足时禁用模型切换但保留打开/隐藏。
- **公开隐私泄漏**：发布前对 Git 历史和工作树分别扫描。
- **Hammerspoon 或 macOS 更新变化**：记录最低版本，模块启动失败隔离，CI 与发布清单保留版本读回。
