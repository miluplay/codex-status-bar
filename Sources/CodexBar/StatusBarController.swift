import AppKit
import CodexBarCore
import ServiceManagement
import UserNotifications

final class StatusBarController: NSObject, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private enum DefaultsKey {
        static let notifyCompleted = "notifyCompleted"
        static let notifyWaiting = "notifyWaiting"
        static let showStatusText = "showStatusText"
        static let showTimer = "showTimer"
        static let showFiveHourUsage = "showFiveHourUsage"
        static let showWeeklyUsage = "showWeeklyUsage"
        static let iconColorMode = "iconColorMode"
        static let iconAnimationMode = "iconAnimationMode"
        static let didShowCodexAvailabilityCheck = "didShowCodexAvailabilityCheck"
        static let didOfferDisableCodexMenuBarIcon = "didOfferDisableCodexMenuBarIcon"
        static let didRegisterStartAtLoginByDefault = "didRegisterStartAtLoginByDefault"
    }

    private enum MenuLayout {
        static let maxWidth: CGFloat = 300
        static let maxStatusItemWidth: CGFloat = 180
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reader = CodexStateReader()
    private let renderer = StatusIconRenderer()
    private let statusDotView = StatusDotView(color: StatusDotPalette.unread)
    private let codexConfigURL = CodexDesktopConfig.defaultConfigURL()
    private let readerQueue = DispatchQueue(label: "CodexBar.reader", qos: .utility)
    private let sessionMenuLimit = 6
    private let pollInterval: TimeInterval = 0.2

    private var notificationTracker = CodexNotificationTracker()
    private var notificationGenerations: [String: Int] = [:]

    private var settingsWindowController: SettingsWindowController?

    private var pollTimer: Timer?
    private var animationTimer: Timer?
    private var animationTimerMode: StatusIconAnimationMode?
    private var animationFrame = 0
    private var isLoading = false
    private var isMenuOpen = false
    private var snapshot = CodexSnapshot.empty()
    private var sessionRows: [String: SessionMenuItemView] = [:]
    private var sessionRowIDs: [String] = []

    private var showStatusText: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showStatusText, defaultValue: false) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showStatusText) }
    }

    private var showTimer: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showTimer, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showTimer) }
    }

    private var showFiveHourUsage: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showFiveHourUsage, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showFiveHourUsage) }
    }

    private var showWeeklyUsage: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.showWeeklyUsage, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.showWeeklyUsage) }
    }

    private var iconColorMode: StatusIconColorMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: DefaultsKey.iconColorMode) ?? StatusIconColorMode.system.rawValue
            return StatusIconColorMode(rawValue: rawValue) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.iconColorMode) }
    }

    private var iconAnimationMode: StatusIconAnimationMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: DefaultsKey.iconAnimationMode) ?? StatusIconAnimationMode.orbit.rawValue
            return StatusIconAnimationMode(rawValue: rawValue) ?? .orbit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.iconAnimationMode) }
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self

        statusItem.autosaveName = "CodexStatusBar.Main"
        statusItem.isVisible = true
        statusItem.button?.setAccessibilityIdentifier("CodexStatusBar.Main")
        statusItem.button?.setAccessibilityLabel("Codex 状态栏")
        statusItem.button?.toolTip = "Codex 状态栏"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.contentTintColor = nil
        statusDotView.isHidden = true
        applyRoundedButtonChrome()

        render()
        loadSnapshot()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        pollTimer = timer

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.runFirstLaunchChecks()
        }
    }

    private func runFirstLaunchChecks() {
        let status = CodexInstallDetector.detect()

        registerStartAtLoginByDefaultIfNeeded()

        if !UserDefaults.standard.bool(forKey: DefaultsKey.didShowCodexAvailabilityCheck, defaultValue: false) {
            UserDefaults.standard.set(true, forKey: DefaultsKey.didShowCodexAvailabilityCheck)
            showCodexAvailabilityAlertIfNeeded(status)
        }

        offerDisableCodexMenuBarIconIfNeeded(status)
    }

    private func registerStartAtLoginByDefaultIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.didRegisterStartAtLoginByDefault, defaultValue: false) else {
            return
        }

        UserDefaults.standard.set(true, forKey: DefaultsKey.didRegisterStartAtLoginByDefault)

        do {
            switch SMAppService.mainApp.status {
            case .notRegistered, .notFound:
                try SMAppService.mainApp.register()
            case .enabled, .requiresApproval:
                return
            @unknown default:
                return
            }
        } catch {
            showAlert(
                message: "Could not enable Start at login",
                informativeText: error.localizedDescription,
                buttons: ["OK"]
            )
        }
    }

    private func showCodexAvailabilityAlertIfNeeded(_ status: CodexInstallStatus) {
        if !status.isInstalled {
            showAlert(
                message: "Codex is not installed",
                informativeText: "Codex Status Bar needs Codex Desktop, the Codex CLI, or an IDE extension to read local activity.",
                buttons: ["OK"]
            )
            return
        }

        guard !status.isRunning else { return }

        if status.desktopAppURL != nil {
            let response = showAlert(
                message: "Codex is not running",
                informativeText: "Open Codex so Codex Status Bar can show live local activity. Recent local sessions may still appear.",
                buttons: ["Open Codex", "Not Now"]
            )

            if response == .alertFirstButtonReturn {
                openCodex()
            }
        } else {
            showAlert(
                message: "Codex is not running",
                informativeText: "Start Codex from your CLI or IDE so Codex Status Bar can show live local activity.",
                buttons: ["OK"]
            )
        }
    }

    private func offerDisableCodexMenuBarIconIfNeeded(_ status: CodexInstallStatus) {
        guard let codexAppURL = status.desktopAppURL,
              !UserDefaults.standard.bool(forKey: DefaultsKey.didOfferDisableCodexMenuBarIcon, defaultValue: false),
              CodexDesktopConfig.menuBarIconEnabled(configURL: codexConfigURL)
        else {
            return
        }

        let response = showAlert(
            message: "Disable Codex's built-in menu bar icon?",
            informativeText: "Codex Status Bar already shows Codex activity in the menu bar, so disabling Codex's own icon prevents duplicate menu bar items.",
            buttons: ["Disable", "Not Now"]
        )

        guard response == .alertFirstButtonReturn else {
            UserDefaults.standard.set(true, forKey: DefaultsKey.didOfferDisableCodexMenuBarIcon)
            return
        }

        do {
            try CodexDesktopConfig.setMenuBarIconEnabled(false, configURL: codexConfigURL)
            UserDefaults.standard.set(true, forKey: DefaultsKey.didOfferDisableCodexMenuBarIcon)
            showCodexRelaunchPrompt(codexAppURL: codexAppURL)
        } catch {
            showAlert(
                message: "Could not update Codex's menu bar setting",
                informativeText: error.localizedDescription,
                buttons: ["OK"]
            )
        }
    }

    private func showCodexRelaunchPrompt(codexAppURL: URL) {
        let isCodexDesktopRunning = isCodexDesktopRunning()
        let response = showAlert(
            message: isCodexDesktopRunning ? "Relaunch Codex now?" : "Open Codex now?",
            informativeText: isCodexDesktopRunning
                ? "Codex Status Bar saved the setting. Relaunch Codex Desktop now to hide the duplicate menu bar icon, or do it later."
                : "Codex Status Bar saved the setting. Open Codex Desktop now to use the new menu bar setting, or do it later.",
            buttons: [isCodexDesktopRunning ? "Relaunch Now" : "Open Now", "Later"]
        )

        guard response == .alertFirstButtonReturn else { return }

        if isCodexDesktopRunning {
            relaunchCodex(at: codexAppURL)
        } else {
            openCodexApplication(at: codexAppURL)
        }
    }

    private func relaunchCodex(at appURL: URL) {
        let runningApplications = runningCodexDesktopApplications()
        guard !runningApplications.isEmpty else {
            openCodexApplication(at: appURL)
            return
        }

        var requestedTermination = false
        for application in runningApplications {
            requestedTermination = application.terminate() || requestedTermination
        }

        guard requestedTermination else {
            showAlert(
                message: "Could not relaunch Codex",
                informativeText: "Codex Status Bar could not ask Codex Desktop to quit. Quit and reopen Codex manually to apply the menu bar setting.",
                buttons: ["OK"]
            )
            return
        }

        openCodexAfterTermination(at: appURL, deadline: Date().addingTimeInterval(8))
    }

    private func openCodexAfterTermination(at appURL: URL, deadline: Date) {
        guard isCodexDesktopRunning() else {
            openCodexApplication(at: appURL)
            return
        }

        guard Date() < deadline else {
            showAlert(
                message: "Codex did not quit",
                informativeText: "Codex Status Bar asked Codex Desktop to quit, but it is still running. Quit and reopen Codex manually to apply the menu bar setting.",
                buttons: ["OK"]
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.openCodexAfterTermination(at: appURL, deadline: deadline)
        }
    }

    private func isCodexDesktopRunning() -> Bool {
        !runningCodexDesktopApplications().isEmpty
    }

    private func runningCodexDesktopApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { application in
            application.bundleIdentifier == "com.openai.codex"
        }
    }

    @discardableResult
    private func showAlert(message: String, informativeText: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = ChinesePresentation.text(message)
        alert.informativeText = ChinesePresentation.text(informativeText)
        alert.alertStyle = .informational
        buttons.forEach { alert.addButton(withTitle: ChinesePresentation.text($0)) }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    private func tick() {
        loadSnapshot()
        render()
    }

    private func loadSnapshot() {
        guard !isLoading else { return }
        isLoading = true

        readerQueue.async { [reader] in
            let next = reader.loadSnapshot()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.sendNotifications(for: next)
                self.snapshot = next
                self.isLoading = false
                self.render()
                self.refreshOpenSessionRows()
            }
        }
    }

    private func render() {
        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: displayOptions(),
            now: Date()
        )
        updateAnimation(active: state.animatesIcon, mode: iconAnimationMode)

        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        statusItem.button?.image = renderer.image(
            active: state.animatesIcon,
            frame: animationFrame,
            colorMode: iconColorMode,
            animationMode: iconAnimationMode,
            appearance: appearance
        )
        let title = ChinesePresentation.text(state.title)
        statusItem.button?.toolTip = "Codex 状态栏：\(title)"
        applyTitle(showStatusText ? title : "", statusDot: state.statusDot)
    }

    private func updateAnimation(active: Bool, mode: StatusIconAnimationMode) {
        if active {
            guard animationTimer == nil || animationTimerMode != mode else { return }
            animationTimer?.invalidate()
            animationTimerMode = mode
            let timer = Timer(timeInterval: mode.frameInterval, repeats: true) { [weak self] _ in
                self?.animationFrame += 1
                self?.render()
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            animationTimerMode = nil
            animationFrame = 0
        }
    }

    private func displayOptions() -> CodexBarDisplayOptions {
        CodexBarDisplayOptions(
            showTimer: showTimer,
            showFiveHourUsage: showFiveHourUsage,
            showWeeklyUsage: showWeeklyUsage
        )
    }

    private func applyTitle(_ title: String, statusDot: CodexBarStatusDot?) {
        guard let button = statusItem.button else { return }
        let title = singleLine(title).trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            button.imagePosition = .imageOnly
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            statusItem.length = 28
            button.layoutSubtreeIfNeeded()
            updateStatusDot(statusDot, in: button, font: .menuFont(ofSize: 13))
            applyRoundedButtonChrome()
            return
        }

        button.imagePosition = .imageLeading
        button.alignment = .left
        button.cell?.alignment = .left
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        button.font = font
        button.cell?.lineBreakMode = .byTruncatingTail

        let buttonTitle = Self.buttonTitle(title, statusDot: statusDot)
        button.title = buttonTitle
        let imageWidth = button.image?.size.width ?? 18
        statusItem.length = min(MenuLayout.maxStatusItemWidth, max(48, ceil(Self.titleWidth(buttonTitle, font: font) + imageWidth + 16)))
        button.layoutSubtreeIfNeeded()
        updateStatusDot(statusDot, in: button, font: font)
        applyRoundedButtonChrome()
    }

    private func updateStatusDot(_ statusDot: CodexBarStatusDot?, in button: NSStatusBarButton, font: NSFont) {
        guard let statusDot else {
            statusDotView.isHidden = true
            return
        }

        if statusDotView.superview !== button {
            button.addSubview(statusDotView)
        }
        statusDotView.update(color: StatusDotPalette.color(for: statusDot))
        let dotSize = statusDotView.intrinsicContentSize
        let buttonHeight = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness
        let titleRect = button.cell?.titleRect(forBounds: button.bounds) ?? button.bounds
        let spaceWidth = Self.titleWidth(" ", font: font)
        let dotSlotWidth = Self.titleWidth(Self.statusDotPlaceholder, font: font)
        if button.title.isEmpty {
            statusDotView.frame = NSRect(
                x: max(0, button.bounds.width - dotSize.width - 2),
                y: max(0, buttonHeight - dotSize.height - 2),
                width: dotSize.width,
                height: dotSize.height
            )
            statusDotView.isHidden = false
            return
        }
        statusDotView.frame = NSRect(
            x: titleRect.minX + spaceWidth + floor((dotSlotWidth - dotSize.width) / 2),
            y: floor((buttonHeight - dotSize.height) / 2),
            width: dotSize.width,
            height: dotSize.height
        )
        statusDotView.isHidden = false
    }

    private static let statusDotPlaceholder = "\u{2007}"

    private static func buttonTitle(_ title: String, statusDot: CodexBarStatusDot?) -> String {
        statusDot == nil ? " \(title)" : " \(Self.statusDotPlaceholder) \(title)"
    }

    private static func titleWidth(_ title: String, font: NSFont) -> CGFloat {
        (title as NSString).size(withAttributes: [.font: font]).width
    }

    private func applyRoundedButtonChrome() {
        guard let button = statusItem.button else { return }
        button.layer?.masksToBounds = false
        button.wantsLayer = false
    }

    func showMenu() {
        guard let menu = statusItem.menu else { return }
        menuNeedsUpdate(menu)
        NSApp.activate(ignoringOtherApps: true)
        // A context menu remains reachable when the status item is hidden or crowded out.
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        sessionRows.removeAll()
        sessionRowIDs.removeAll()

        addStatusRows(to: menu)
        menu.addItem(.separator())
        let sessionsHeader = disabledItem("Sessions")
        sessionsHeader.identifier = NSUserInterfaceItemIdentifier("sessionsHeader")
        menu.addItem(sessionsHeader)
        addSessionRows(to: menu)

        menu.addItem(.separator())
        let openItem = NSMenuItem(title: "打开 Codex", action: #selector(openCodex), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        addQuickActions(to: menu)
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quit = NSMenuItem(title: "退出 Codex 状态栏", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        refreshOpenSessionRows()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        sessionRows.removeAll()
        sessionRowIDs.removeAll()
    }

    private func addSessionRows(to menu: NSMenu) {
        sessionRowIDs.removeAll()
        let sessions = visibleMenuSessions()

        guard !sessions.isEmpty else {
            menu.addItem(disabledItem("No active or unread sessions"))
            return
        }

        for session in sessions {
            menu.addItem(sessionMenuItem(for: session))
        }
    }

    private func visibleMenuSessions() -> [CodexSession] {
        CodexBarPresentation.visibleMenuSessions(snapshot: snapshot, limit: sessionMenuLimit)
    }

    private func sessionMenuItem(for session: CodexSession) -> NSMenuItem {
        let item = NSMenuItem()
        let view = SessionMenuItemView(width: MenuLayout.maxWidth, session: session, now: snapshot.generatedAt) { [weak self, weak item] currentSession in
            item?.menu?.cancelTracking()
            self?.openCodexThread(currentSession)
        }
        item.view = view
        item.toolTip = session.statusLabel.map(ChinesePresentation.text)
        sessionRows[sessionRowKey(for: session)] = view
        sessionRowIDs.append(sessionRowKey(for: session))
        return item
    }

    private func refreshOpenSessionRows() {
        guard isMenuOpen, let menu = statusItem.menu else { return }

        let sessions = visibleMenuSessions()
        let nextIDs = sessions.map(sessionRowKey)

        guard nextIDs == sessionRowIDs else {
            replaceSessionRows(in: menu, with: sessions)
            return
        }

        for session in sessions {
            sessionRows[sessionRowKey(for: session)]?.update(session: session, now: snapshot.generatedAt)
        }
    }

    private func sessionRowKey(for session: CodexSession) -> String {
        session.rolloutPath
    }

    private func replaceSessionRows(in menu: NSMenu, with sessions: [CodexSession]) {
        guard let headerIndex = menu.items.firstIndex(where: {
            $0.identifier == NSUserInterfaceItemIdentifier("sessionsHeader")
        }) else { return }
        let startIndex = headerIndex + 1

        var endIndex = startIndex
        while endIndex < menu.numberOfItems,
              menu.item(at: endIndex)?.isSeparatorItem == false {
            endIndex += 1
        }

        if endIndex > startIndex {
            for index in stride(from: endIndex - 1, through: startIndex, by: -1) {
                menu.removeItem(at: index)
            }
        }

        sessionRows.removeAll()
        sessionRowIDs.removeAll()

        if sessions.isEmpty {
            menu.insertItem(disabledItem("No active or unread sessions"), at: startIndex)
            return
        }

        for (offset, session) in sessions.enumerated() {
            menu.insertItem(sessionMenuItem(for: session), at: startIndex + offset)
        }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let settings = SettingsWindowController(version: ChinesePresentation.text(versionTitle()))
            settings.addSection("显示")
            settings.addToggle("显示状态文字", state: { [weak self] in self?.showStatusText == true ? .on : .off }, action: { [weak self] in self?.toggleStatusText() })
            settings.addToggle("显示运行计时", state: { [weak self] in self?.showTimer == true ? .on : .off }, action: { [weak self] in self?.toggleTimer() })
            settings.addToggle("显示 5 小时额度", state: { [weak self] in self?.showFiveHourUsage == true ? .on : .off }, action: { [weak self] in self?.toggleFiveHourUsage() })
            settings.addToggle("显示周额度", state: { [weak self] in self?.showWeeklyUsage == true ? .on : .off }, action: { [weak self] in self?.toggleWeeklyUsage() })
            settings.addSection("外观")
            settings.addChoice("图标颜色", options: StatusIconColorMode.allCases.map { (ChinesePresentation.text($0.title), $0.rawValue) }, selected: { [weak self] in self?.iconColorMode.rawValue ?? StatusIconColorMode.system.rawValue }) { [weak self] value in
                guard let self, let mode = StatusIconColorMode(rawValue: value) else { return }
                self.iconColorMode = mode
                self.render()
            }
            settings.addChoice("动画效果", options: StatusIconAnimationMode.allCases.map { (ChinesePresentation.text($0.title), $0.rawValue) }, selected: { [weak self] in self?.iconAnimationMode.rawValue ?? StatusIconAnimationMode.orbit.rawValue }) { [weak self] value in
                guard let self, let mode = StatusIconAnimationMode(rawValue: value) else { return }
                self.iconAnimationMode = mode
                self.render()
            }
            settings.addSection("通知")
            for (title, key) in [("任务完成通知", DefaultsKey.notifyCompleted), ("等待输入或授权通知", DefaultsKey.notifyWaiting)] {
                settings.addToggle(title, state: { UserDefaults.standard.bool(forKey: key) ? .on : .off }) { [weak self] in
                    self?.toggleNotification(key: key)
                }
            }
            settings.addSection("通用")
            settings.addToggle("开机启动", state: { [weak self] in self?.startAtLoginMenuState() ?? .off }, action: { [weak self] in self?.toggleStartAtLogin() })
            settingsWindowController = settings
        }
        settingsWindowController?.present()
    }

    private func addStatusRows(to menu: NSMenu) {
        let now = Date()

        menu.addItem(disabledItem(UsageFormatter.leftLine(snapshot.usage?.primary, fallbackLabel: "5h")))
        menu.addItem(disabledItem(UsageFormatter.leftLine(snapshot.usage?.secondary, fallbackLabel: "Week")))
        menu.addItem(disabledItem(UsageFormatter.resetLine(snapshot.usage?.primary, fallbackLabel: "5h", now: now)))
        menu.addItem(disabledItem(UsageFormatter.resetLine(snapshot.usage?.secondary, fallbackLabel: "Week", now: now)))

        if let lastError = snapshot.lastError?.nilIfEmpty {
            menu.addItem(disabledItem(truncate("Data: \(lastError)", limit: 30)))
        }
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let title = truncate(ChinesePresentation.text(title), limit: 30)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func versionTitle() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "Version \(version)"
    }

    private func startAtLoginMenuState() -> NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        case .notRegistered, .notFound:
            return .off
        @unknown default:
            return .off
        }
    }

    private func addQuickActions(to menu: NSMenu) {
        let projects = NSMenuItem(title: "项目快捷操作", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        var paths = Set<String>()
        for session in visibleMenuSessions() where session.cwd.hasPrefix("/") && paths.insert(session.cwd).inserted {
            let project = NSMenuItem(title: URL(fileURLWithPath: session.cwd).lastPathComponent, action: nil, keyEquivalent: "")
            project.toolTip = session.cwd
            let actions = NSMenu()
            for (title, selector) in [("在 Finder 中打开", #selector(openProject(_:))), ("复制项目路径", #selector(copyProjectPath(_:)))] {
                let action = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                action.target = self
                action.representedObject = session.cwd
                actions.addItem(action)
            }
            project.submenu = actions
            submenu.addItem(project)
        }
        if submenu.items.isEmpty { submenu.addItem(disabledItem("暂无可用项目")) }
        projects.submenu = submenu
        menu.addItem(projects)
    }

    @objc private func openProject(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        if !NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true)) {
            showAlert(message: "无法打开项目目录", informativeText: "目录可能已移动或删除。", buttons: ["OK"])
        }
    }

    @objc private func copyProjectPath(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func toggleNotification(key: String) {
        let generation = (notificationGenerations[key] ?? 0) + 1
        notificationGenerations[key] = generation
        if UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(false, forKey: key)
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self, self.notificationGenerations[key] == generation else { return }
                UserDefaults.standard.set(granted, forKey: key)
                self.settingsWindowController?.refresh()
                if !granted {
                    self.showAlert(message: "通知未开启", informativeText: error?.localizedDescription ?? "请在系统设置 > 通知中允许 Codex 状态栏发送通知，然后重新开启此选项。", buttons: ["OK"])
                }
            }
        }
    }

    private func sendNotifications(for next: CodexSnapshot) {
        for event in notificationTracker.update(next) {
            let key = event.kind == .completed ? DefaultsKey.notifyCompleted : DefaultsKey.notifyWaiting
            guard UserDefaults.standard.bool(forKey: key) else { continue }
            let content = UNMutableNotificationContent()
            switch event.kind {
            case .completed: content.title = "Codex 任务已完成"
            case .input: content.title = "Codex 等待你的输入"
            case .approval: content.title = "Codex 等待你的授权"
            }
            content.body = event.project.isEmpty ? "打开 Codex 查看会话。" : "项目：\(event.project)"
            content.sound = .default
            content.userInfo = ["sessionID": event.sessionID]
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error { NSLog("Codex Status Bar notification: %@", error.localizedDescription) }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let sessionID = response.notification.request.content.userInfo["sessionID"] as? String
        DispatchQueue.main.async { [weak self] in
            if let sessionID, let url = CodexBarPresentation.codexThreadURL(for: sessionID), NSWorkspace.shared.open(url) {
                completionHandler()
                return
            }
            self?.openCodex()
            completionHandler()
        }
    }

    @objc private func openCodex() {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            openCodexApplication(at: appURL)
            return
        }

        let fallbackURL = URL(fileURLWithPath: "/Applications/Codex.app")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            openCodexApplication(at: fallbackURL)
        }
    }

    private func openCodexApplication(at appURL: URL) {
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func openCodexThread(_ session: CodexSession) {
        guard let threadURL = CodexBarPresentation.codexThreadURL(for: session.id),
              NSWorkspace.shared.open(threadURL)
        else {
            openCodex()
            return
        }
    }

    @objc private func toggleStatusText() {
        showStatusText.toggle()
        render()
    }

    @objc private func toggleTimer() {
        showTimer.toggle()
        render()
    }

    @objc private func toggleFiveHourUsage() {
        showFiveHourUsage.toggle()
        render()
    }

    @objc private func toggleWeeklyUsage() {
        showWeeklyUsage.toggle()
        render()
    }

    @objc private func toggleStartAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled:
                try SMAppService.mainApp.unregister()
            case .notRegistered, .notFound:
                try SMAppService.mainApp.register()
            case .requiresApproval:
                showAlert(
                    message: "Approve Start at login in System Settings",
                    informativeText: "Open System Settings > General > Login Items & Extensions, then allow Codex Status Bar.",
                    buttons: ["OK"]
                )
            @unknown default:
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(
                message: "Could not update Start at login",
                informativeText: error.localizedDescription,
                buttons: ["OK"]
            )
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func truncate(_ value: String, limit: Int) -> String {
        CodexBarPresentation.truncate(value, limit: limit)
    }

    private func singleLine(_ value: String) -> String {
        CodexBarPresentation.singleLine(value)
    }

}

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private enum StatusDotPalette {
    static let approval = NSColor(calibratedRed: CGFloat(0x42) / 255, green: CGFloat(0xc6) / 255, blue: CGFloat(0x77) / 255, alpha: 1)
    static let unread = NSColor(calibratedRed: CGFloat(0x83) / 255, green: CGFloat(0xc4) / 255, blue: CGFloat(0xff) / 255, alpha: 1)

    static func color(for statusDot: CodexBarStatusDot) -> NSColor {
        switch statusDot {
        case .approval:
            return approval
        case .unread:
            return unread
        }
    }
}

private final class SessionMenuItemView: NSView {
    private enum LeadingIndicator: Equatable {
        case approval
        case active
        case unread
        case disclosure
    }

    private static let rowHeight: CGFloat = 24
    private static let iconBoxWidth: CGFloat = 10
    private static let indicatorTitleSpacing: CGFloat = 5

    private let width: CGFloat
    private var session: CodexSession
    private var renderedIndicator: LeadingIndicator?
    private var iconConstraints: [NSLayoutConstraint] = []
    private let iconBox = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let badgeView: BadgeView
    private let chevronView = NSImageView()
    private let clickHandler: (CodexSession) -> Void

    private var isOpenable: Bool {
        session.client == .app
    }

    private var trackingArea: NSTrackingArea?
    private var highlighted = false {
        didSet {
            updateColors()
            needsDisplay = true
        }
    }

    init(width: CGFloat, session: CodexSession, now: Date, clickHandler: @escaping (CodexSession) -> Void) {
        self.width = width
        self.session = session
        self.badgeView = BadgeView(text: session.client?.rawValue)
        self.clickHandler = clickHandler

        super.init(frame: NSRect(origin: .zero, size: NSSize(width: width, height: Self.rowHeight)))

        setupLayout()
        update(session: session, now: now)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: width, height: Self.rowHeight)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSSize(width: min(newSize.width, width), height: Self.rowHeight))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard highlighted else { return }

        NSColor.controlAccentColor.setFill()
        let rect = bounds.insetBy(dx: 5, dy: 1)
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard isOpenable else { return }
        highlighted = true
    }

    override func mouseExited(with event: NSEvent) {
        highlighted = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isOpenable else { return }
        clickHandler(session)
    }

    func update(session: CodexSession, now: Date) {
        self.session = session
        if !isOpenable {
            highlighted = false
        }
        toolTip = session.statusLabel.map(ChinesePresentation.text)

        titleLabel.stringValue = session.title
        badgeView.update(text: session.client?.rawValue)
        updateIconIfNeeded(indicator: leadingIndicator(for: session))
        updateElapsedTime(now: now)
        updateColors()
    }

    private func setupLayout() {
        iconBox.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .menuFont(ofSize: 13)
        configureSingleLineLabel(titleLabel, lineBreakMode: .byTruncatingTail)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        configureSingleLineLabel(timeLabel, lineBreakMode: .byTruncatingTail)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        badgeView.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeView.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [iconBox, titleLabel, timeLabel, badgeView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.detachesHiddenViews = true
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.distribution = .fill
        stack.setCustomSpacing(Self.indicatorTitleSpacing, after: iconBox)
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: Self.iconBoxWidth),
            iconBox.heightAnchor.constraint(equalToConstant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func updateIconIfNeeded(indicator: LeadingIndicator) {
        guard renderedIndicator != indicator else { return }

        NSLayoutConstraint.deactivate(iconConstraints)
        iconConstraints.removeAll()
        iconBox.subviews.forEach { $0.removeFromSuperview() }
        renderedIndicator = indicator

        switch indicator {
        case .approval:
            let dotView = StatusDotView(color: StatusDotPalette.approval)
            dotView.translatesAutoresizingMaskIntoConstraints = false
            iconBox.addSubview(dotView)

            iconConstraints = [
                dotView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                dotView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                dotView.widthAnchor.constraint(equalToConstant: 7),
                dotView.heightAnchor.constraint(equalToConstant: 7),
            ]

        case .active:
            let spinner = NSProgressIndicator()
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isIndeterminate = true
            spinner.isDisplayedWhenStopped = true
            spinner.startAnimation(nil)
            iconBox.addSubview(spinner)

            iconConstraints = [
                spinner.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                spinner.widthAnchor.constraint(equalToConstant: 12),
                spinner.heightAnchor.constraint(equalToConstant: 12),
            ]

        case .unread:
            let dotView = StatusDotView(color: StatusDotPalette.unread)
            dotView.translatesAutoresizingMaskIntoConstraints = false
            iconBox.addSubview(dotView)

            iconConstraints = [
                dotView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                dotView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                dotView.widthAnchor.constraint(equalToConstant: 7),
                dotView.heightAnchor.constraint(equalToConstant: 7),
            ]

        case .disclosure:
            chevronView.translatesAutoresizingMaskIntoConstraints = false
            chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
            chevronView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular)
            iconBox.addSubview(chevronView)

            iconConstraints = [
                chevronView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                chevronView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
                chevronView.widthAnchor.constraint(equalToConstant: 8),
                chevronView.heightAnchor.constraint(equalToConstant: 10),
            ]
        }

        NSLayoutConstraint.activate(iconConstraints)
    }

    private func leadingIndicator(for session: CodexSession) -> LeadingIndicator {
        if let statusLabel = session.statusLabel,
           CodexBarPresentation.isApprovalLabel(statusLabel) {
            return .approval
        }

        if session.isActive {
            return .active
        }

        if session.isUnread {
            return .unread
        }

        return .disclosure
    }

    private func updateColors() {
        let primaryColor: NSColor
        let secondaryColor: NSColor

        if highlighted {
            primaryColor = .selectedMenuItemTextColor
            secondaryColor = .selectedMenuItemTextColor.withAlphaComponent(0.84)
        } else if session.isActive || session.isUnread {
            primaryColor = .labelColor
            secondaryColor = .secondaryLabelColor
        } else {
            primaryColor = .secondaryLabelColor
            secondaryColor = .tertiaryLabelColor
        }

        titleLabel.textColor = primaryColor
        timeLabel.textColor = secondaryColor
        chevronView.contentTintColor = secondaryColor
        badgeView.rowHighlighted = highlighted
    }

    private func updateElapsedTime(now: Date) {
        let timeText = session.activeStartedAt.map { ChinesePresentation.text(Self.elapsedText(since: $0, now: now)) } ?? ""
        guard timeLabel.stringValue != timeText || timeLabel.isHidden != timeText.isEmpty else { return }

        timeLabel.stringValue = timeText
        timeLabel.isHidden = timeText.isEmpty
        timeLabel.invalidateIntrinsicContentSize()
        needsLayout = true
    }

    private static func elapsedText(since start: Date, now: Date) -> String {
        CodexBarPresentation.elapsedText(since: start, now: now)
    }

    private func configureSingleLineLabel(_ label: NSTextField, lineBreakMode: NSLineBreakMode) {
        label.lineBreakMode = lineBreakMode
        label.maximumNumberOfLines = 1
        label.usesSingleLineMode = true
        label.cell?.wraps = false
        label.cell?.isScrollable = false
        label.cell?.lineBreakMode = lineBreakMode
    }
}

private final class StatusDotView: NSView {
    private var color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    func update(color: NSColor) {
        guard !self.color.isEqual(color) else { return }

        self.color = color
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 7, height: 7)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

private final class BadgeView: NSButton {
    private var text: String?
    private let badgeFont = NSFont.systemFont(ofSize: 10, weight: .semibold)

    var rowHighlighted = false {
        didSet {
            updateTitleColor()
        }
    }

    init(text: String?) {
        self.text = nil
        super.init(frame: .zero)
        setupLayout()
        update(text: text)
    }

    func update(text: String?) {
        guard self.text != text else { return }

        self.text = text
        isHidden = text == nil
        title = text ?? ""
        updateTitleColor()
        invalidateIntrinsicContentSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        guard text != nil else { return .zero }

        let size = super.intrinsicContentSize
        return NSSize(width: max(30, ceil(size.width)), height: ceil(size.height))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func setupLayout() {
        bezelStyle = .badge
        controlSize = .small
        font = badgeFont
        imagePosition = .noImage
        alignment = .center
        isBordered = true
        isTransparent = false
        focusRingType = .none
        refusesFirstResponder = true
        setButtonType(.momentaryChange)
    }

    private func updateTitleColor() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: rowHighlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor,
        ]
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }
}
