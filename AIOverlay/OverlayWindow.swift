import AppKit
import SwiftUI

final class OverlayWindow: NSPanel {
    init<Content: View>(rootView: Content) {
        let rect = NSRect(x: 200, y: 200, width: 460, height: 320)
        super.init(contentRect: rect,
                   styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: AnyView(rootView))
    }
}
