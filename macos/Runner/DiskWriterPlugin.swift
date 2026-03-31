import Cocoa
import FlutterMacOS

/// Method channel plugin that provides the path to the bundled diskwriter binary.
/// The diskwriter binary handles macOS Authorization Services (Touch ID / password dialog)
/// and authopen fd-passing to get authorized write access to raw disk devices.
class DiskWriterPlugin {
    static let channelName = "org.librescoot.installer/disk_writer"

    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDiskwriterPath":
            result(diskwriterPath())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func diskwriterPath() -> String? {
        return Bundle.main.path(forResource: "diskwriter", ofType: nil)
    }
}
