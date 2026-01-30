import Foundation
import AppKit
import Combine

/// Manager for handling Screen Recording and Accessibility permissions
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    /// Whether screen recording permission is granted
    @Published var isScreenRecordingGranted: Bool = false

    /// Whether accessibility permission is granted
    @Published var isAccessibilityGranted: Bool = false

    /// Timer for checking permission status
    private var checkTimer: Timer?

    /// Flag to prevent repeated screen recording checks while system dialog is open
    private var isCheckingScreenRecording: Bool = false

    private init() {
        checkPermissions()
        // Don't auto-start monitoring - let the UI start it when needed
    }

    deinit {
        checkTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Check all permissions
    func checkPermissions() {
        checkScreenRecordingPermission()
        checkAccessibilityPermission()
    }

    /// Check screen recording permission
    func checkScreenRecordingPermission() {
        // Use CGPreflightScreenCaptureAccess to check permission without triggering dialog
        // This is the recommended way on macOS 10.15+
        let hasAccess = CGPreflightScreenCaptureAccess()

        DispatchQueue.main.async { [weak self] in
            self?.isScreenRecordingGranted = hasAccess
        }
    }

    /// Check accessibility permission
    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async { [weak self] in
            if self?.isAccessibilityGranted != trusted {
                self?.isAccessibilityGranted = trusted
            }
        }
    }

    /// Request screen recording permission
    func requestScreenRecordingPermission() {
        // Open System Settings to Screen Recording
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Request accessibility permission
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async { [weak self] in
            self?.isAccessibilityGranted = trusted
        }
        return trusted
    }

    /// Open Screen Recording settings
    func openScreenRecordingSettings() {
        // Open System Settings directly to Screen Recording
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open Accessibility settings
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Show app in Finder (for drag and drop to settings)
    func showAppInFinder() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.selectFile(bundleURL.path, inFileViewerRootedAtPath: bundleURL.deletingLastPathComponent().path)
    }

    /// Restart the app
    func restartApp() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }

        let script = """
            sleep 0.5
            open "\(bundlePath)"
            """

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        try? task.run()

        NSApp.terminate(nil)
    }

    /// Start monitoring for permission changes
    func startMonitoring() {
        checkTimer?.invalidate()
        checkTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
        RunLoop.main.add(checkTimer!, forMode: .common)
    }

    /// Stop monitoring
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    /// Whether all required permissions are granted
    var allPermissionsGranted: Bool {
        isScreenRecordingGranted && isAccessibilityGranted
    }
}
