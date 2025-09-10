import Foundation
import AppKit
import Vision
import ScreenCaptureKit
import AVFoundation

final class ScreenContext {
    /// Capture the main display, gather a bit of metadata about the
    /// foreground window, run OCR on the screenshot and return everything as
    /// a textual blob suitable for sending as chat context.
    func getContextText() async -> String {
        guard let cgImage = await captureMainDisplay() else {
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

    /// Capture the main display into a `CGImage` using ScreenCaptureKit.
    private func captureMainDisplay() async -> CGImage? {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                return nil
            }

            let filter = SCContentFilter(display: display,
                                         excludingApplications: [],
                                         excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.queueDepth = 1

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let collector = FrameCollector()
            try stream.addStreamOutput(collector, type: .screen,
                                       sampleHandlerQueue: DispatchQueue.global())

            try await stream.startCapture()
            defer { Task { try? await stream.stopCapture() } }

            guard let sample = await collector.nextSample(),
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                return nil
            }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            return context.createCGImage(ciImage, from: ciImage.extent)
        } catch {
            return nil
        }
    }
}

/// Helper output to collect a single frame from `SCStream`.
private final class FrameCollector: NSObject, SCStreamOutput {
    private var continuation: CheckedContinuation<CMSampleBuffer?, Never>?

    func nextSample() async -> CMSampleBuffer? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        continuation?.resume(returning: sampleBuffer)
        continuation = nil
    }
}
