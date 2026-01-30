import Foundation
import AppKit
import SwiftUI

/// Service for managing floating screenshot windows
class FloatingWindowService: ObservableObject {
    static let shared = FloatingWindowService()

    @Published var floatingWindows: [UUID: NSWindow] = [:]

    private init() {}

    // MARK: - Public Methods

    /// Pin a screenshot as a floating window
    func pinScreenshot(_ screenshot: Screenshot) {
        let windowSize = calculateWindowSize(for: screenshot.image)

        // Create floating window
        let window = FloatingWindow(
            contentRect: NSRect(
                x: 100,
                y: 100,
                width: windowSize.width,
                height: windowSize.height
            ),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = FloatingScreenshotView(
            screenshot: screenshot,
            onClose: { [weak self] in
                self?.closeFloatingWindow(id: screenshot.id)
            },
            onOpacityChange: { [weak window] opacity in
                window?.alphaValue = opacity
            }
        )

        window.contentView = NSHostingView(rootView: contentView)

        // Position near cursor
        if let mouseLocation = NSEvent.mouseLocation as CGPoint? {
            window.setFrameOrigin(NSPoint(
                x: mouseLocation.x - windowSize.width / 2,
                y: mouseLocation.y - windowSize.height / 2
            ))
        }

        window.makeKeyAndOrderFront(nil)
        floatingWindows[screenshot.id] = window
    }

    /// Close a specific floating window
    func closeFloatingWindow(id: UUID) {
        floatingWindows[id]?.close()
        floatingWindows.removeValue(forKey: id)
    }

    /// Close all floating windows
    func closeAllFloatingWindows() {
        for (_, window) in floatingWindows {
            window.close()
        }
        floatingWindows.removeAll()
    }

    /// Toggle pin state for a screenshot
    func togglePin(_ screenshot: Screenshot) {
        if floatingWindows[screenshot.id] != nil {
            closeFloatingWindow(id: screenshot.id)
        } else {
            pinScreenshot(screenshot)
        }
    }

    /// Check if a screenshot is pinned
    func isPinned(_ screenshot: Screenshot) -> Bool {
        return floatingWindows[screenshot.id] != nil
    }

    // MARK: - Private Methods

    private func calculateWindowSize(for image: NSImage) -> NSSize {
        let maxDimension: CGFloat = 400
        let imageSize = image.size

        if imageSize.width > imageSize.height {
            let ratio = maxDimension / imageSize.width
            return NSSize(
                width: maxDimension,
                height: min(imageSize.height * ratio, maxDimension)
            )
        } else {
            let ratio = maxDimension / imageSize.height
            return NSSize(
                width: min(imageSize.width * ratio, maxDimension),
                height: maxDimension
            )
        }
    }
}

// MARK: - Floating Window Class
class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        // ESC to close
        if event.keyCode == 53 {
            close()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Floating Screenshot View
struct FloatingScreenshotView: View {
    let screenshot: Screenshot
    let onClose: () -> Void
    let onOpacityChange: (CGFloat) -> Void

    @State private var isHovered = false
    @State private var opacity: Double = 1.0
    @State private var showControls = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Screenshot image
            Image(nsImage: screenshot.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            // Controls overlay
            if isHovered {
                VStack(alignment: .trailing, spacing: 8) {
                    // Close button
                    ControlButton(icon: "xmark", action: onClose)

                    // Copy button
                    ControlButton(icon: "doc.on.doc") {
                        copyToClipboard()
                    }

                    // Opacity slider
                    if showControls {
                        VStack(spacing: 4) {
                            Text("\(Int(opacity * 100))%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)

                            Slider(value: $opacity, in: 0.2...1.0)
                                .frame(width: 80)
                                .onChange(of: opacity) { _, newValue in
                                    onOpacityChange(newValue)
                                }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                    }

                    // Toggle controls button
                    ControlButton(icon: showControls ? "chevron.up" : "slider.horizontal.3") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    }
                }
                .padding(8)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([screenshot.image])
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.black.opacity(isHovered ? 0.9 : 0.7))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
