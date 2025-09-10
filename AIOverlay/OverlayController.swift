import AppKit
import SwiftUI

final class OverlayController {
    private var window: OverlayWindow?

    func toggle<Content: View>(rootView: Content) {
        if let w = window, w.isVisible {
            w.orderOut(nil)
            return
        }
        if window == nil {
            window = OverlayWindow(rootView: rootView)
        } else {
            window?.contentView = NSHostingView(rootView: AnyView(rootView))
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setContent<Content: View>(rootView: Content) {
        if window == nil {
            window = OverlayWindow(rootView: rootView)
        }
        window?.contentView = NSHostingView(rootView: AnyView(rootView))
    }
}
