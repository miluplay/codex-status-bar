# Codex Status Bar

## 个人定制版

本 fork 的第一轮定制：

- 中文菜单、状态、计时、用量说明和首次启动提示。
- 下拉菜单在菜单栏图标下方按系统原生方式定位，集中展示额度、重置时间和会话状态；点击「设置…」（⌘,）打开独立窗口，按会话状态、用量显示、外观、通知、通用分组配置，即时生效。再次打开会聚焦已有窗口，原有偏好自动保留。在设置窗口按 ⌘Q 可退出应用。
- 会话栏优先显示本地会话索引中的会话名称，重命名后随刷新更新；索引缺失或名称为空时回退到项目名称。项目快捷操作继续使用项目目录。
- 菜单栏 5H、7D 可分别选择「隐藏 / 空闲时显示 / 始终显示」；始终显示的额度固定在状态文字前，关闭状态文字仍保留额度。状态菜单中的 5H、7D 有独立显示开关。额度细线与菜单栏图标不显示悬停提示，图例说明放在设置中。
- 额度使用 `5H` / `7D` 侧标细线：灰色显示已用额度，蓝色游标显示周期时间进度；线下左侧显示重置时间、右侧显示剩余额度。在「设置… > 用量显示」中开启「额度重置时间使用数字倒计时」，即可从文字切换为数字：5H 使用 `时:分:秒`（例如 `2:59:59`），7D 使用 `天:时:分`（例如 `6:23:59`）；菜单打开期间实时更新。
- 默认只占 28 像素宽显示图标，减少菜单栏空间占用。「设置… > 会话状态 > 显示状态文字」可恢复菜单栏文字。授权／未读状态圆点在图标模式下仍显示。
- Codex 运行时使用彩色图标，未运行时使用黑白图标；会话正在处理时播放所选动画，等待输入或授权时保持静止。
- 启动或再次打开应用时不自动弹出菜单。定制版使用独立标识 `io.github.miluplay.codexstatusbar`，显示选项和通知权限与上游版本分开保存。
- 菜单栏图标：单指点击立即打开状态菜单，双指点击（右键／Control 点击）打开设置。
- 打开菜单后可用 ⌘O 打开 Codex；「项目快捷操作」可在 Finder 中打开活跃／未读会话的项目，或复制项目路径。
- 独立的「设置…」窗口中可分别开启任务完成通知、等待输入或授权通知。通知默认关闭，开启时申请 macOS 通知权限；点击通知打开对应 Codex 会话。CLI／IDE 会话能否直接打开取决于 Codex 桌面应用的支持。
- 通知只包含状态和项目目录名，不显示提示词或会话正文；启动时不补发历史通知，同一等待状态不重复通知，取消任务不报完成。

本地构建：`./Engineering/Build/build.sh --release`，产物位于 `Engineering/Build/build/CodexStatusBar.app`。

`./Engineering/Build/build_and_run.sh --verify` 会构建调试版，再运行临时目录中的应用副本；验证输出包含该副本的 PID 和可执行文件路径。它会覆盖 `Engineering/Build/build/` 中的构建产物。活动监视器中进程名为 `CodexStatusBar`，应用提供独立设置窗口，没有 Dock 图标。

同一应用标识只保留一个运行实例。如果 Applications 中也安装了此定制版，打开其他副本会唤起已有实例。要验证最新本地构建，请先退出已安装的定制版，再执行启动验证脚本；否则实际运行的可能仍是旧副本。

## 项目目录

```text
Sources/                  # 应用和核心逻辑源码
Package.swift             # Swift 包与测试目录配置
Engineering/
├── Build/
│   ├── build.sh           # 构建应用、打包 DMG
│   ├── build_and_run.sh   # 构建调试版并启动
│   └── build/             # 构建产物，不纳入版本控制
├── Tests/
│   └── CodexBarCoreTests/ # 核心逻辑自动化测试
└── Release/
    ├── VERSION            # 用户可见版本号
    ├── BUILD_NUMBER       # 构建编号
    ├── CHANGELOG.md       # 版本更新记录
    └── Formula/           # Homebrew 安装配方
```

构建和测试命令从项目根目录执行；Swift 编译缓存仍位于根目录的 `.build/`。测试入口仍为 `swift test`。Homebrew 配方兼容本 fork 的新目录和上游源码目录。

以下为上游项目说明，Homebrew 和下载链接仍指向上游版本。

A compact native macOS menu bar app that shows what Codex is doing locally.

No window or dock icon. No network calls.

<img width="1280" height="720" alt="CodexStatusBar v2" src="https://github.com/user-attachments/assets/bae186fb-beea-45b8-bea5-e86888f598b7" />

## What It Shows

- **Thinking / working** - an animated status icon with an optional live timer.
- **Running a tool** - compact labels such as `Editing`, `Reading`, `Running command`, or `Web search`.
- **Waiting for input or approval** - paused status when Codex needs a reply or permission.
- **Multiple agents** - compact counts such as `2 agents running 4m 12s` or `2 waiting 1m 0s`, timed from the newest active agent.
- **Unread sessions** - a blue-dot status for unread finished Codex sessions, and local usage indicators.
- **Idle / done** - local usage indicators.

The menu includes active and unread sessions, `APP` / `CLI` / `IDE` badges, usage reset details, an Options submenu for toggles, animation controls, and the app version.

## Requirements

- macOS 13+
- Codex Desktop, the Codex CLI, or a Codex IDE extension.

## Install

### Homebrew

Recommended for developers. Homebrew builds Codex Status Bar from source and launches the app from Homebrew's install location.

```bash
brew tap yuriipalam/codex-status-bar https://github.com/yuriipalam/codex-status-bar
brew trust --formula yuriipalam/codex-status-bar/codex-status-bar
brew install codex-status-bar
codex-status-bar
```

To update this canary install:

```bash
brew update
brew reinstall codex-status-bar
```

### DMG

<p>
  <a href="https://github.com/yuriipalam/codex-status-bar/releases/latest/download/CodexStatusBar.dmg">
    <img alt="Download for Mac OS" src="https://img.shields.io/static/v1?label=&message=Download%20for%20Mac%20OS&color=000000&style=for-the-badge&logo=apple&logoColor=white">
  </a>
</p>

Download the latest DMG, open it, then drag `CodexStatusBar.app` into `Applications`.

The DMG is not Developer ID signed or notarized yet. If macOS blocks the first launch, keep the app and remove the downloaded-app quarantine:

```bash
xattr -dr com.apple.quarantine /Applications/CodexStatusBar.app
open /Applications/CodexStatusBar.app
```

You can also use Apple's UI override: try opening the app once, then open System Settings > Privacy & Security and click `Open Anyway`. Apple documents that flow in [Safely open apps on your Mac](https://support.apple.com/en-us/102445).

### Uninstall

Turn off `Options` > `Start at login` before uninstalling.

For Homebrew:

```bash
brew uninstall codex-status-bar
```

For DMG installs, remove `/Applications/CodexStatusBar.app`.

Removing the app does not remove saved display options. To remove local Codex Status Bar settings too:

```bash
defaults delete io.github.yuriipalam.codexstatusbar 2>/dev/null || true
rm -f ~/Library/Preferences/io.github.yuriipalam.codexstatusbar.plist
```

If the app was removed before Start at login was turned off, remove the stale item from System Settings > General > Login Items & Extensions.

## How It Works

Codex Status Bar resolves `CODEX_HOME`, falls back to `~/.codex`, and polls local Codex session JSONL plus Codex's unread-thread state every 0.2 seconds. It derives status, elapsed time, tool labels, unread sessions, and usage snapshots from local files only.

Those Codex files are implementation details, not a stable public API. If Codex changes its local file format, Codex Status Bar may need an update.

## Privacy

Codex Status Bar reads local Codex activity files and processes them on your Mac. It does not display prompts, responses, command output, or generated thread summaries, and it does not upload telemetry, call OpenAI APIs, install hooks, or modify session logs.

Codex Status Bar stores local display options in macOS preferences and registers itself as a login item on first launch; you can turn Start at login off from `Options`. The only write to Codex config is user-approved: on first launch, Codex Status Bar can disable Codex Desktop's own duplicate menu bar icon by writing `[desktop] mac-menu-bar-enabled = false` to `$CODEX_HOME/config.toml`.

Development, source builds, and packaging live in [CONTRIBUTING.MD](CONTRIBUTING.MD). Release notes live in [CHANGELOG.md](Engineering/Release/CHANGELOG.md).

## Acknowledgements

Thanks to [m1ckc3s](https://github.com/m1ckc3s) and his [Claude Status Bar](https://github.com/m1ckc3s/claude-status-bar) project. The original idea started there for Claude, this app is a Codex-focused take inspired by that work.

## Trademark / Not Affiliated

This is an unofficial open-source side project. It is not affiliated with, endorsed by, or sponsored by OpenAI.

Codex and OpenAI are trademarks of OpenAI. The app includes Codex icon assets for local menu-bar display. The MIT license covers this project's source code only and does not grant rights to OpenAI names, trademarks, or brand assets.

## License

MIT
