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
- Grouped provider layout in the menu and dashboard
- Per-service failure summary
- "Only show issues" filter
- HTTP/HTTPS proxy test
- Manual launch at login via LaunchAgent
- Bilingual UI: English and Simplified Chinese
- Default language follows macOS system language

### Product behavior

- Click the menu bar icon to open the grouped status menu
- Open the dashboard only from the menu entry
- Each provider is grouped and summarized instead of being shown as one flat list
- API keys are stored in macOS Keychain
- App preferences are stored in UserDefaults

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

### Notes

- This project currently uses Swift Package Manager and does not require a full Xcode project for local development.
- The generated `.app` bundle is unsigned.
- Launch at login works only when the packaged `.app` is used.
- Some providers currently use web-level reachability checks only, because a stable public API path suitable for generic availability testing is not available.

### Planned roadmap

- Quota and balance monitoring
- Provider-level enable/disable switches
- Search and quick filters
- Custom compact popover UI closer to dedicated commercial menu bar tools
- Signed release builds

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
- 菜单和面板里的服务分组布局
- 每个服务的失败原因摘要
- `仅显示异常项` 过滤
- HTTP/HTTPS 代理测试
- 基于 LaunchAgent 的手动开机启动
- 中英双语界面
- 默认语言跟随 macOS 系统语言

### 产品行为

- 点击状态栏图标打开分组状态菜单
- 只有点击菜单中的“打开面板”才会弹出可视化窗口
- 服务按组和按服务汇总显示，不再是一整串平铺结果
- API Key 保存到 macOS Keychain
- 应用设置保存到 UserDefaults

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

### 说明

- 这个项目目前基于 Swift Package Manager 开发，本地不需要完整 Xcode 工程即可运行。
- 当前生成的 `.app` 还没有签名。
- 开机自启只在使用打包后的 `.app` 时生效。
- 部分服务目前只做网页级连通性检测，因为没有适合通用可用性探测的稳定公开 API 入口。

### 后续计划

- 接入额度、余额、配额监控
- 每个服务单独启用/禁用
- 搜索与快速筛选
- 更接近商业菜单栏工具的自定义紧凑浮层 UI
- 签名发行版
