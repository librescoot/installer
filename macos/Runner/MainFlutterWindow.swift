import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var diskWriterPlugin: DiskWriterPlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Same default as the Linux and Windows runners, rather than whatever
    // size the nib happened to carry.
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    diskWriterPlugin = DiskWriterPlugin(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
