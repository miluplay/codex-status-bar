import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller: StatusBarController

    init(controller: StatusBarController) {
        self.controller = controller
        super.init()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if let bundleID = Bundle.main.bundleIdentifier,
   NSWorkspace.shared.runningApplications.contains(where: {
       $0.bundleIdentifier == bundleID && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
   }) {
    exit(0)
}

// Register the status item before entering the AppKit run loop, as upstream does.
let delegate = AppDelegate(controller: StatusBarController())
app.delegate = delegate
app.run()
withExtendedLifetime(delegate) {}
