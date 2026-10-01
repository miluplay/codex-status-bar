import AppKit

/// A single reusable settings window. Controls read their state from the app so
/// failed permission requests and changes made in System Settings stay in sync.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let stack = NSStackView()
    private var refreshers: [() -> Void] = []
    private var actions: [() -> Void] = []

    init(version: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex 状态栏设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.setFrameAutosaveName("CodexStatusBar.Settings")

        guard let content = window.contentView else { return }
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
        ])

        let subtitle = NSTextField(wrappingLabelWithString: "调整菜单栏显示与通知，修改后立即生效。")
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(subtitle)
        let versionLabel = NSTextField(labelWithString: version)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.font = .systemFont(ofSize: 11)
        // Keep version information in the window rather than in the status menu.
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(versionLabel)
        NSLayoutConstraint.activate([
            versionLabel.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            versionLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: versionLabel.topAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func addSection(_ title: String) {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(label)
    }

    func addDescription(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 404
        stack.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    func addToggle(_ title: String, state: @escaping () -> NSControl.StateValue, action: @escaping () -> Void) {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(performAction(_:)))
        button.allowsMixedState = true
        button.tag = actions.count
        actions.append(action)
        refreshers.append { button.state = state() }
        stack.addArrangedSubview(button)
    }

    func addChoice(_ title: String, options: [(title: String, value: String)], selected: @escaping () -> String, action: @escaping (String) -> Void) {
        let label = NSTextField(labelWithString: title)
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        for option in options {
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.value
        }
        popup.target = self
        popup.action = #selector(performAction(_:))
        popup.tag = actions.count
        actions.append {
            guard let value = popup.selectedItem?.representedObject as? String else { return }
            action(value)
        }
        refreshers.append {
            if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selected() }) {
                popup.select(item)
            }
        }
        let row = NSStackView(views: [label, popup])
        row.spacing = 16
        label.widthAnchor.constraint(equalToConstant: 80).isActive = true
        popup.widthAnchor.constraint(equalToConstant: 230).isActive = true
        stack.addArrangedSubview(row)
    }

    func present() {
        refresh()
        if window?.isVisible != true { window?.center() }
        window?.deminiaturize(nil)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func refresh() { refreshers.forEach { $0() } }

    func windowDidBecomeKey(_ notification: Notification) { refresh() }

    @objc private func performAction(_ sender: NSControl) {
        actions[sender.tag]()
        refresh()
    }
}
