import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Without this the window can be dragged down to any size at all. The
    // sidebar is 280pt on its own, so below roughly 640pt of width there is
    // nothing left for the terminal and the layout overflows — at 200pt it
    // renders Flutter's "RIGHT OVERFLOWED BY 80 PIXELS" bar instead of an
    // interface. 640x480 is the smallest size where a terminal is still
    // usable next to a collapsed sidebar.
    self.contentMinSize = NSSize(width: 640, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
