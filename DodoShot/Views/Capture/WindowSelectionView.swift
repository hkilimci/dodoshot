import SwiftUI
import AppKit

struct WindowSelectionView: View {
    let windows: [WindowInfo]
    let onSelect: (WindowInfo) -> Void
    let onCancel: () -> Void
    var title: String = L10n.WindowSelection.title + " • " + L10n.WindowSelection.escToCancel

    @State private var hoveredWindowID: CGWindowID?

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Instructions
            VStack {
                InstructionBadge(text: title)
                    .padding(.top, 60)
                Spacer()
            }

            // Window highlights
            ForEach(windows, id: \.windowID) { window in
                WindowHighlight(
                    window: window,
                    isHovered: hoveredWindowID == window.windowID,
                    onHover: { isHovered in
                        hoveredWindowID = isHovered ? window.windowID : nil
                    },
                    onSelect: {
                        onSelect(window)
                    }
                )
            }
        }
        .background(
            KeyEventHandler(onEscape: onCancel)
        )
    }
}

// MARK: - Window Highlight
struct WindowHighlight: View {
    let window: WindowInfo
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let screenFrame = NSScreen.main?.frame ?? .zero
            let windowFrame = CGRect(
                x: window.frame.origin.x,
                y: screenFrame.height - window.frame.origin.y - window.frame.height,
                width: window.frame.width,
                height: window.frame.height
            )

            ZStack {
                // Window frame highlight
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHovered ?
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.white.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                        lineWidth: isHovered ? 3 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHovered ? Color.blue.opacity(0.1) : Color.clear)
                    )

                // App name label when hovered
                if isHovered {
                    VStack {
                        WindowInfoBadge(window: window)
                            .padding(.top, 8)
                        Spacer()
                    }
                }
            }
            .frame(width: windowFrame.width, height: windowFrame.height)
            .position(x: windowFrame.midX, y: windowFrame.midY)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    onHover(hovering)
                }
            }
            .onTapGesture {
                onSelect()
            }
        }
    }
}

// MARK: - Window Info Badge
struct WindowInfoBadge: View {
    let window: WindowInfo

    var body: some View {
        HStack(spacing: 8) {
            // App icon
            if let bundleID = window.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                AsyncAppIcon(appURL: appURL)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(window.ownerName ?? "Unknown")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                if let title = window.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Async App Icon
struct AsyncAppIcon: View {
    let appURL: URL

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

// MARK: - Key Event Handler
struct KeyEventHandler: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyEventNSView {
        let view = KeyEventNSView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyEventNSView, context: Context) {}
}

class KeyEventNSView: NSView {
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscape?()
        }
    }
}
