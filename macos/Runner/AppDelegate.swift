import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var isWorker: Bool {
    CommandLine.arguments.contains("--worker")
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    if isWorker {
      _ = NSApp.setActivationPolicy(.accessory)
      NSApp.windows.forEach { $0.orderOut(nil) }
    }
    super.applicationWillFinishLaunching(notification)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if isWorker {
      NSApp.windows.forEach { $0.orderOut(nil) }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    if isWorker {
      return false
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
