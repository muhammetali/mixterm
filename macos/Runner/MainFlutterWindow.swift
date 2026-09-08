import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The key the window's frame is remembered under.
  ///
  /// Carries a version suffix so that changing the first-run size actually
  /// reaches people who have run the app before: without it, an install
  /// that had already saved a frame would restore it forever and never see
  /// the new default. Bump the number when the default changes in a way
  /// existing users should be given once.
  private static let frameAutosaveName = "MixTermMainWindow.v1"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // macOS has two mechanisms for putting a window back where it was, and
    // they fight. State restoration — on by default, and kept on by
    // `applicationSupportsSecureRestorableState` in AppDelegate — reapplies
    // its own remembered frame about 700ms after launch, well after this
    // method has returned. Measured, with everything below already correct:
    //
    //     a_nib   = (280, 165, 1232, 772)   <- what we set up
    //     e_later = (46, 353, 800, 632)     <- what the user saw
    //
    // Restoration wins because it acts last, which also means a new default
    // could never reach anyone who had run the app before. So this window
    // opts out and uses frame autosave below, which we can version.
    self.isRestorable = false

    // Assigning the content view controller resizes the window to fit the
    // Flutter view, which at this point has no size at all — measured, the
    // window collapses to 1x32 and does not recover on its own. So the
    // frame the nib gave us is captured first and put back afterwards. This
    // is the one line of the Flutter template that looks redundant and is
    // not.
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

    // Remember whatever size the user settles on and restore it next
    // launch. A default only has to be right once; after that the window
    // should come back the way they left it.
    //
    // Naming the frame is all this takes — AppKit saves on resize and
    // restores on load. The first-run size deliberately is not set here: it
    // comes from the contentRect in MainMenu.xib, which AppKit applies to
    // this window before `awakeFromNib` runs. See that file for the
    // derivation of 1232x740 — briefly, a 120x40 terminal beside the 280pt
    // sidebar, under the 36pt tab bar and the 40pt toolbar, at the roughly
    // 7.8x16.2pt cell the default font gives.
    self.setFrameAutosaveName(MainFlutterWindow.frameAutosaveName)
  }

  /// Keeps the window inside the display it is on.
  ///
  /// The nib asks for 1232x740, comfortable on any current screen but taller
  /// than the usable area of an old 1280x800 laptop once the menu bar and
  /// Dock are taken out. AppKit's own constraining keeps the title bar
  /// reachable; this also stops the window from being wider or taller than
  /// the space available, so a first launch on a small display opens as a
  /// window rather than something running off the edge.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    var constrained = super.constrainFrameRect(frameRect, to: screen)

    guard let visible = (screen ?? self.screen ?? NSScreen.main)?.visibleFrame else {
      return constrained
    }

    constrained.size.width = min(constrained.size.width, visible.width)
    constrained.size.height = min(constrained.size.height, visible.height)
    return constrained
  }
}
