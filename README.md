# AI OpsBar

English | [简体中文](#简体中文)

## English

AI OpsBar is a native macOS menu bar utility for monitoring whether major AI products and APIs are reachable and actually usable from your current network.

It is designed for users who work across multiple AI services and want one lightweight status bar tool for:

- Reachability monitoring
- API availability checks
- Proxy-path verification
- Multi-provider visibility
- Future quota and usage tracking

### Current scope

AI OpsBar currently monitors:

- OpenAI Codex
- Gemini
- Claude
- Cursor
- GitHub Copilot
- AntiGravity
- Droid
- Z.ai
- MiniMax
- DeepSeek

For supported providers, AI OpsBar can also verify API usability when you provide an API key through the built-in Keychain-backed key manager.

### Features

- Native macOS menu bar app
- Low-background-overhead polling strategy
- Custom-drawn status bar icon states
- Left-click quick status popover with top issues and recent health
- Grouped provider layout in the menu and dashboard
- Per-service failure summary
- Persistent per-service health history
- Codex spend and usage visibility across 5 hours, 1 day, 7 days, 1 month, and all time
- Notification center alerts for outages, recovery, and quota warnings
- Custom user-defined services with editable web/API probes
- "Only show issues" filter
- HTTP/HTTPS proxy test
- Manual launch at login via LaunchAgent
- Bilingual UI: English and Simplified Chinese
- Default language follows macOS system language

### Product behavior

- Left-click the menu bar icon to open the quick status popover
- Right-click the menu bar icon to open the grouped context menu
- Open the full dashboard from the popover or the context menu
- Each provider is grouped and summarized instead of being shown as one flat list
- API keys are stored in macOS Keychain
- App preferences, history, and custom services are stored in UserDefaults
- For Codex, quota is read from the local `codex app-server`, and spend/usage windows are derived from local session logs

### Monitoring depth

| Provider | Web | API | Quota / Usage | Spend / Cost |
| --- | --- | --- | --- | --- |
| Codex | Yes | Yes | Local `codex app-server`, with local log fallback | Local `~/.codex/sessions` and `~/.codex/archived_sessions`; shows USD if exposed, otherwise token windows |
| Gemini | Yes | Yes | Not exposed in-app yet; console-level only | No |
| Claude | Yes | Yes | Anthropic org usage API when an admin key is available | No |
| Cursor | Yes | Yes | No | No |
| GitHub Copilot | Yes | No | No | No |
| AntiGravity | Yes | No | No | No |
| Droid | Yes | No | No | No |
| Z.ai | Yes | Yes | Response-body usage parsing | No |
| MiniMax | Yes | Yes | Response-body usage parsing | No |
| DeepSeek | Yes | Yes | Response-body usage parsing | No |
| Custom services | Configurable | Configurable | Response-header based when available | No |

### Quick start

1. Build and launch the app.
2. Add API keys for the providers you want to verify beyond simple web reachability.
3. Use left click for the quick health popover and right click for the grouped context menu.
4. Open the dashboard to manage custom services, proxies, notifications, and launch-at-login.

### Build and run

Development:

```bash
cd /Users/cwn/Desktop/所有文件夹/一些实用小工具/AI-OpsBar
swift run AIOpsBar
```

Build a double-clickable app bundle:

```bash
cd /Users/cwn/Desktop/所有文件夹/一些实用小工具/AI-OpsBar
./scripts/build_app.sh
open "dist/AI OpsBar.app"
```

Launch the packaged app directly from Terminal:

```bash
open -na "/Users/cwn/Desktop/所有文件夹/一些实用小工具/AI-OpsBar/dist/AI OpsBar.app"
```

### Notes

- This project currently uses Swift Package Manager and does not require a full Xcode project for local development.
- The generated `.app` bundle is unsigned.
- Launch at login works only when the packaged `.app` is used.
- Some providers currently use web-level reachability checks only, because a stable public API path suitable for generic availability testing is not available.
- Codex local spend currently depends on what the local session logs expose. On machines where only token usage is available, AI OpsBar shows token windows instead of USD cost.
- Codex window totals can be identical across `5h`, `1d`, `7d`, `30d`, and `all` when your local logs all fall within the latest 5 hours; that is expected behavior, not a UI bug.

### Planned roadmap

- Deeper quota and balance coverage for more providers
- Exportable diagnostics and uptime reports
- Signed release builds
- Optional auto-update delivery

---

## 简体中文

AI OpsBar 是一个原生 macOS 状态栏工具，用来监控当前网络下主流 AI 产品和 API 是否可连通、是否真正可用。

它适合同时使用多个 AI 服务的用户，把这些能力统一收敛到一个轻量级状态栏插件里：

- 连通性监控
- API 可用性检测
- 代理链路验证
- 多服务统一可视化
- 后续接入额度与用量监控

### 当前支持

AI OpsBar 目前可检测：

- OpenAI Codex
- Gemini
- Claude
- Cursor
- GitHub Copilot
- AntiGravity
- Droid
- Z.ai
- MiniMax
- DeepSeek

对于支持公开 API 的服务，你还可以通过内置的 Keychain 密钥管理录入 API Key，从而检测“API 是否真的可用”，而不仅仅是网络是否可达。

### 当前特性

- 原生 macOS 状态栏应用
- 低后台占用轮询策略
- 自绘状态栏图标
- 左键快速状态浮层，可直接查看重点异常和最近健康状态
- 菜单和面板里的服务分组布局
- 每个服务的失败原因摘要
- 每个服务的持久化健康历史
- 对 Codex 显示 5 小时、1 天、7 天、1 个月、全部的金额 / 用量窗口
- 故障、恢复、低配额的通知中心提醒
- 支持用户自定义服务和自定义网页/API 检测
- `仅显示异常项` 过滤
- HTTP/HTTPS 代理测试
- 基于 LaunchAgent 的手动开机启动
- 中英双语界面
- 默认语言跟随 macOS 系统语言

### 产品行为

- 左键点击状态栏图标打开快速状态浮层
- 右键点击状态栏图标打开分组上下文菜单
- 可以从浮层或菜单进入完整面板
- 服务按组和按服务汇总显示，不再是一整串平铺结果
- API Key 保存到 macOS Keychain
- 应用设置、历史记录和自定义服务保存到 UserDefaults
- 对 Codex，配额来自本地 `codex app-server`，金额 / 用量窗口来自本地 session 日志

### 监控深度

| 服务 | Web | API | 配额 / 用量 | 金额 / 成本 |
| --- | --- | --- | --- | --- |
| Codex | 支持 | 支持 | 本地 `codex app-server`，不可用时回退到本地日志 | 来自 `~/.codex/sessions` 和 `~/.codex/archived_sessions`；如果本地暴露 USD 就显示金额，否则显示 token 窗口 |
| Gemini | 支持 | 支持 | 当前应用里未接真实额度接口，控制台级为主 | 不支持 |
| Claude | 支持 | 支持 | 如果有 Anthropic admin key，可走组织级 usage API | 不支持 |
| Cursor | 支持 | 支持 | 不支持 | 不支持 |
| GitHub Copilot | 支持 | 不支持 | 不支持 | 不支持 |
| AntiGravity | 支持 | 不支持 | 不支持 | 不支持 |
| Droid | 支持 | 不支持 | 不支持 | 不支持 |
| Z.ai | 支持 | 支持 | 可从响应体里的 usage 解析部分用量 | 不支持 |
| MiniMax | 支持 | 支持 | 可从响应体里的 usage 解析部分用量 | 不支持 |
| DeepSeek | 支持 | 支持 | 可从响应体里的 usage 解析部分用量 | 不支持 |
| 自定义服务 | 可配置 | 可配置 | 如果响应头暴露配额字段，可做 header 级监控 | 不支持 |

### 快速开始

1. 先构建并启动应用。
2. 给你想深度校验的服务填入 API Key，这样监控不只是网页能不能打开。
3. 左键看快速健康状态，右键看分组菜单。
4. 在完整面板里管理自定义服务、代理、通知和开机启动。

### 运行与打包

开发运行：

```bash
cd /Users/cwn/Desktop/所有文件夹/一些实用小工具/AI-OpsBar
swift run AIOpsBar
```

打包为可双击启动的 `.app`：

```bash
cd /Users/cwn/Desktop/所有文件夹/一些实用小工具/AI-OpsBar
./scripts/build_app.sh
open "dist/AI OpsBar.app"
```

直接从终端启动打包后的应用：

```bash
open -na "/Users/cwn/Desktop/所有文件夹/一些实用小工具/AI-OpsBar/dist/AI OpsBar.app"
```

### 说明

- 这个项目目前基于 Swift Package Manager 开发，本地不需要完整 Xcode 工程即可运行。
- 当前生成的 `.app` 还没有签名。
- 开机自启只在使用打包后的 `.app` 时生效。
- 部分服务目前只做网页级连通性检测，因为没有适合通用可用性探测的稳定公开 API 入口。
- Codex 的本地金额能力取决于本机 session 日志里暴露的数据；如果本地只有 token 用量而没有 USD 成本，AI OpsBar 会显示 token 窗口。
- 如果本机所有 Codex 本地日志都落在最近 5 小时内，那么 `5小时 / 1天 / 7天 / 1个月 / 全部` 这些窗口出现相同数值是正常现象，不是 UI 出错。

### 后续计划

- 为更多服务补齐更深的额度/余额监控
- 导出诊断报告和可用率统计
- 签名发行版
- 可选自动更新分发
