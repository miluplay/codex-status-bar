# Contributing

Thanks for helping improve Codex Status Bar. Keep the app local-first, read-only for Codex activity data, and small enough to remain easy to inspect.

## Development

```bash
swift test
./Engineering/Build/build_and_run.sh --verify
```

To test against a custom Codex state directory:

```bash
CODEX_HOME=/path/to/custom/codex ./Engineering/Build/build_and_run.sh
```

Generated build artifacts should stay untracked:

- `.build/`
- `Engineering/Build/build/`
- `dist/`
- `.codex/`
- `.swiftpm/`
- `DerivedData/`

## Build

```bash
swift test
./Engineering/Build/build.sh --release
```

The release app bundle is written to:

```text
Engineering/Build/build/CodexStatusBar.app
```

The build script assembles and signs the app in a temporary staging directory, then copies final outputs into `Engineering/Build/build/`. This keeps Finder/File Provider metadata away from the app bundle used for packaging.

## Packaging

Create a local DMG:

```bash
./Engineering/Build/build.sh --dmg
hdiutil verify Engineering/Build/build/CodexStatusBar.dmg
```

The DMG is written to:

```text
Engineering/Build/build/CodexStatusBar.dmg
```

## Homebrew

The formula lives in:

```text
Engineering/Release/Formula/codex-status-bar.rb
```

Check Ruby syntax locally:

```bash
ruby -c Engineering/Release/Formula/codex-status-bar.rb
```

After the formula is pushed to the tap, validate the published install path:

```bash
brew tap yuriipalam/codex-status-bar https://github.com/yuriipalam/codex-status-bar
brew trust --formula yuriipalam/codex-status-bar/codex-status-bar
brew audit --formula yuriipalam/codex-status-bar/codex-status-bar
brew install codex-status-bar
codex-status-bar
```

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

```text
type: summary
```

Examples:

- `feat: show unread Codex sessions`
- `fix: ignore malformed JSONL lines`
- `docs: simplify product copy`

## 当前本机工具链的测试参数

部分 Swift 6.4 Command Line Tools 的默认构建系统找不到 TestingMacros，
原生构建系统又缺少 Testing.framework 搜索路径。本次在此环境使用以下命令通过测试：

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache" \
swift test --disable-sandbox --build-system native \
  --cache-path "$PWD/.build/swiftpm-cache" \
  -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

在 Codex 的文件系统沙盒中，编译缓存需放在工作目录中：

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache" \
SWIFT_BUILD_FLAGS='--disable-sandbox --build-system native' ./Engineering/Build/build.sh --release
```

这些是当前本机工具链的临时兼容参数；其他环境优先使用上面的标准开发命令。
