import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Tamaño tipo iPhone (390x844) para diseñar pensando en mobile.
    let phoneSize = NSSize(width: 390, height: 844)
    let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let originX = (screenFrame.width - phoneSize.width) / 2
    let originY = (screenFrame.height - phoneSize.height) / 2
    let windowFrame = NSRect(x: originX, y: originY, width: phoneSize.width, height: phoneSize.height)

    self.setFrame(windowFrame, display: true)
    self.minSize = phoneSize
    self.maxSize = phoneSize

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
