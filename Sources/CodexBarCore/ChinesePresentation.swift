import Foundation

/// Translates display copy without changing the parser's canonical status labels.
public enum ChinesePresentation {
    private static let copy: [String: String] = [
        "Open Codex": "打开 Codex", "Sessions": "会话", "Loading sessions": "正在读取会话…", "No active or unread sessions": "暂无活跃或未读会话",
        "运行中": "运行中", "等待中": "等待中", "已暂停": "已暂停", "已退出": "已退出", "空闲": "空闲", "未知": "未知",
        "Quit Codex Status Bar": "退出 Codex 状态栏", "Options": "选项", "Show timer": "显示计时",
        "Show 5-hour usage": "显示 5 小时用量", "Show weekly usage": "显示每周用量", "Start at login": "登录时启动",
        "Color": "颜色", "Animation": "动画", "System": "跟随系统", "Colorful": "彩色",
        "Orbit": "环绕", "Pulse": "呼吸", "Pulsing Orbit": "呼吸环绕", "Idle": "空闲",
        "Awaiting approval": "等待授权", "Waiting for approval": "等待授权", "Waiting for input": "等待输入", "Needs input": "等待输入",
        "Thinking": "思考中", "Thinking...": "思考中", "Reasoning": "思考中", "Working": "处理中", "Settings": "应用设置",
        "Rolling back": "回退中", "Web search": "搜索网页", "Tool search": "搜索工具", "Searching": "搜索中",
        "Viewing": "查看图片", "Image": "生成图片", "Writing": "写入中", "Running JS": "运行 JS",
        "Email": "读取邮件", "Querying": "查询数据", "Using tools": "使用工具", "Using tool": "使用工具",
        "Running command": "运行命令", "Sending input": "发送输入", "Editing": "编辑中", "Reading": "读取中",
        "Searching web": "搜索网页", "Searching tools": "搜索工具", "Searching files": "搜索文件",
        "Creating image": "生成图片", "Viewing image": "查看图片", "Planning": "规划中", "Checking goal": "检查目标",
        "Updating goal": "更新目标", "Using app": "操作应用", "Reading email": "读取邮件", "Querying data": "查询数据",
        "Using MCP": "使用 MCP", "Reviewing edits": "检查修改", "Reviewing output": "检查输出", "Reading results": "读取结果",
        "Inspecting image": "检查图片", "Reviewing data": "检查数据", "Checking app": "检查应用",
        "Writing update": "更新进度", "Compacting context": "压缩上下文", "Applying settings": "应用设置",
        "OK": "好", "Not Now": "暂不", "Disable": "关闭", "Later": "稍后", "Relaunch Now": "立即重启", "Open Now": "立即打开",
        "Codex is not installed": "尚未安装 Codex", "Codex is not running": "Codex 未运行",
        "Codex Status Bar needs Codex Desktop, the Codex CLI, or an IDE extension to read local activity.": "需要安装 Codex 桌面应用、CLI 或 IDE 扩展才能读取本地活动。",
        "Open Codex so Codex Status Bar can show live local activity. Recent local sessions may still appear.": "打开 Codex 后即可显示实时活动。最近的本地会话仍可能显示。",
        "Start Codex from your CLI or IDE so Codex Status Bar can show live local activity.": "请在终端或 IDE 中启动 Codex，以显示实时活动。",
        "Disable Codex's built-in menu bar icon?": "关闭 Codex 自带的菜单栏图标？",
        "Codex Status Bar already shows Codex activity in the menu bar, so disabling Codex's own icon prevents duplicate menu bar items.": "此应用已在菜单栏显示 Codex 活动，关闭自带图标可避免重复显示。",
        "Could not update Codex's menu bar setting": "无法更新 Codex 菜单栏设置",
        "Relaunch Codex now?": "现在重启 Codex？", "Open Codex now?": "现在打开 Codex？",
        "Codex Status Bar saved the setting. Relaunch Codex Desktop now to hide the duplicate menu bar icon, or do it later.": "设置已保存。重启 Codex 后会隐藏重复图标，也可以稍后重启。",
        "Codex Status Bar saved the setting. Open Codex Desktop now to use the new menu bar setting, or do it later.": "设置已保存。打开 Codex 后即可应用，也可以稍后打开。",
        "Approve Start at login in System Settings": "请在系统设置中允许登录时启动",
        "Open System Settings > General > Login Items & Extensions, then allow Codex Status Bar.": "打开系统设置 > 通用 > 登录项与扩展，允许 Codex 状态栏。",
        "Could not update Start at login": "无法更新登录启动设置"
    ]

    private static func duration(_ value: String) -> String {
        value.replacingOccurrences(of: #"(\d+)h\b"#, with: "$1小时", options: .regularExpression)
            .replacingOccurrences(of: #"(\d+)m\b"#, with: "$1分", options: .regularExpression)
            .replacingOccurrences(of: #"(\d+)s\b"#, with: "$1秒", options: .regularExpression)
    }

    public static func text(_ value: String) -> String {
        if let translated = copy[value] { return translated }
        // Status titles may append elapsed time. Match whole labels, never user content.
        for label in copy.keys.sorted(by: { $0.count > $1.count }) where value.hasPrefix(label + " ") {
            let suffix = String(value.dropFirst(label.count))
            if suffix.range(of: #"^ (\d+h \d+m|\d+m \d+s|\d+s)$"#, options: .regularExpression) != nil {
                return copy[label]! + duration(suffix)
            }
        }
        var result = value
        for (pattern, replacement) in [
            (#"^(\d+) agents running"#, "$1 个代理运行中"), (#"^(\d+) waiting"#, "$1 个代理等待中"),
            (#"^(\d+) unread"#, "$1 个未读"), (#"^Version "#, "版本 "), (#"^Data: "#, "数据："),
            (#"\b5h\b"#, "5 小时"), (#"\b[Ww]eek\b"#, "每周"),
            (#" left: "#, " 剩余："), (#" reset: "#, " 重置："), (#"\bnow\b"#, "现在"),
            (#"(\d+)d\b"#, "$1天"), (#"(\d+)h\b"#, "$1小时"), (#"(\d+)m\b"#, "$1分"), (#"(\d+)s\b"#, "$1秒"),
            (#" left$"#, "后"), (#" ago$"#, "前")
        ] {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return result
    }
}
