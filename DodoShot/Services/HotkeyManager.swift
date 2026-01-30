import Foundation
import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func registerHotkeys() {
        // Check accessibility permissions without prompting
        // The prompt should only be shown from the permission UI, not here
        let trusted = AXIsProcessTrusted()

        if !trusted {
            print("Accessibility permissions required for global hotkeys")
            return
        }

        // Already registered, don't register again
        if eventTap != nil {
            return
        }

        // Create event tap for key combinations
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return HotkeyManager.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private static func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for Command + Shift modifiers
        let hasCmd = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)

        if hasCmd && hasShift {
            switch keyCode {
            case 21: // Key '4' - Area capture
                DispatchQueue.main.async {
                    ScreenCaptureService.shared.startCapture(type: .area)
                }
                return nil

            case 23: // Key '5' - Window capture
                DispatchQueue.main.async {
                    ScreenCaptureService.shared.startCapture(type: .window)
                }
                return nil

            case 20: // Key '3' - Fullscreen capture
                DispatchQueue.main.async {
                    ScreenCaptureService.shared.startCapture(type: .fullscreen)
                }
                return nil

            default:
                break
            }
        }

        return Unmanaged.passRetained(event)
    }

    func unregisterHotkeys() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
