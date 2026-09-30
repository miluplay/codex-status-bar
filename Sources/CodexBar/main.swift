import AppKit

private let showMenuNotification = Notification.Name("io.github.miluplay.codexstatusbar.showMenu")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller: StatusBarController
    private var reopenObserver: NSObjectProtocol?

    init(controller: StatusBarController) {
        self.controller = controller
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        reopenObserver = DistributedNotificationCenter.default().addObserver(
            forName: showMenuNotification,
            object: Bundle.main.bundleIdentifier,
            queue: .main
        ) { [weak self] _ in
            self?.controller.showMenu()
        }
        // Give Finder launches visible feedback even when a menu bar manager hides the icon.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.controller.showMenu()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Return from the reopen Apple event before starting menu tracking.
        DispatchQueue.main.async { [weak self] in
            self?.controller.showMenu()
        }
        return false
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if let bundleID = Bundle.main.bundleIdentifier,
   let existing = NSWorkspace.shared.runningApplications.first(where: {
       $0.bundleIdentifier == bundleID && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
   }) {
    DistributedNotificationCenter.default().postNotificationName(
        showMenuNotification, object: bundleID, userInfo: nil, deliverImmediately: true
    )
    existing.activate(options: [])
    exit(0)
}

// Register the status item before entering the AppKit run loop, as upstream does.
let delegate = AppDelegate(controller: StatusBarController())
app.delegate = delegate
app.run()
withExtendedLifetime(delegate) {}
