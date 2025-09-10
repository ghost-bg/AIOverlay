import Foundation
import AppKit
import Vision

final class ScreenContext {
    /// Capture the main display, gather a bit of metadata about the
    /// foreground window, run OCR on the screenshot and return everything as
    /// a textual blob suitable for sending as chat context.
    func getContextText() async -> String {
        guard let cgImage = captureMainDisplay() else {
            return "(screenshot failed)"
        }

        var meta: [String] = []

        // Frontmost application name and window title if available
        if let app = NSWorkspace.shared.frontmostApplication {
            meta.append("Frontmost app: \(app.localizedName ?? "?")")

            let pid = app.processIdentifier
            if let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                        kCGNullWindowID) as? [[String: Any]] {
                if let front = windows.first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid &&
                                                      ($0[kCGWindowLayer as String] as? Int) == 0 }) {
                    if let title = front[kCGWindowName as String] as? String, !title.isEmpty {
                        meta.append("Window title: \(title)")
                    }
                }
            }
        }

        meta.append("Resolution: \(cgImage.width)x\(cgImage.height)")

        // OCR the screenshot
        let request = VNRecognizeTextRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var text = ""
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            text = observations.compactMap { $0.topCandidates(1).first?.string }
                                 .joined(separator: "\n")
        } catch {
            text = "(OCR failed: \(error.localizedDescription))"
        }

        return (meta + ["", text]).joined(separator: "\n")
    }

    /// Capture the main display into a `CGImage` using Core Graphics.
    private func captureMainDisplay() -> CGImage? {
        CGWindowListCreateImage(.infinite,
                                [.optionOnScreenOnly, .excludeDesktopElements],
                                kCGNullWindowID,
                                [.bestResolution, .boundsIgnoreFraming])
    }
}
