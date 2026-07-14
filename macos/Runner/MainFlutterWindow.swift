import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let isWorker = CommandLine.arguments.contains("--worker")
    if isWorker {
      _ = NSApp.setActivationPolicy(.accessory)
      alphaValue = 0
    }

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    if isWorker {
      orderOut(nil)
    }
  }
}
