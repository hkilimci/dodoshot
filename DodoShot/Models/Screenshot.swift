import Foundation
import AppKit

/// Represents a captured screenshot with metadata
struct Screenshot: Identifiable {
    let id: UUID
    let image: NSImage
    let capturedAt: Date
    let captureType: CaptureType
    var annotations: [Annotation]
    var extractedText: String?
    var aiDescription: String?

    init(
        id: UUID = UUID(),
        image: NSImage,
        capturedAt: Date = Date(),
        captureType: CaptureType,
        annotations: [Annotation] = [],
        extractedText: String? = nil,
        aiDescription: String? = nil
    ) {
        self.id = id
        self.image = image
        self.capturedAt = capturedAt
        self.captureType = captureType
        self.annotations = annotations
        self.extractedText = extractedText
        self.aiDescription = aiDescription
    }
}

/// Type of screen capture
enum CaptureType: String, CaseIterable {
    case area = "Area"
    case window = "Window"
    case fullscreen = "Fullscreen"

    var icon: String {
        switch self {
        case .area: return "rectangle.dashed"
        case .window: return "macwindow"
        case .fullscreen: return "rectangle.inset.filled"
        }
    }

    var shortcut: String {
        switch self {
        case .area: return "⌘⇧4"
        case .window: return "⌘⇧5"
        case .fullscreen: return "⌘⇧3"
        }
    }
}

/// Annotation on a screenshot
struct Annotation: Identifiable {
    let id: UUID
    var type: AnnotationType
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var strokeWidth: CGFloat
    var text: String?
    var points: [CGPoint]  // For freehand drawing

    init(
        id: UUID = UUID(),
        type: AnnotationType,
        startPoint: CGPoint,
        endPoint: CGPoint = .zero,
        color: NSColor = .systemRed,
        strokeWidth: CGFloat = 3.0,
        text: String? = nil,
        points: [CGPoint] = []
    ) {
        self.id = id
        self.type = type
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.strokeWidth = strokeWidth
        self.text = text
        self.points = points
    }
}

/// Types of annotations available
enum AnnotationType: String, CaseIterable {
    case select = "Select"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    case text = "Text"
    case blur = "Blur"
    case highlight = "Highlight"
    case freehand = "Freehand"

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .blur: return "drop.halffull"
        case .highlight: return "highlighter"
        case .freehand: return "pencil.tip"
        }
    }
}

/// App appearance mode
enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon.fill"
        }
    }
}

/// Image format for saving
enum ImageFormat: String, Codable, CaseIterable {
    case png = "PNG"
    case jpg = "JPG"
    case auto = "Auto"

    var icon: String {
        switch self {
        case .png: return "doc.richtext"
        case .jpg: return "photo"
        case .auto: return "wand.and.stars"
        }
    }
}

/// App settings model
struct AppSettings: Codable {
    var llmApiKey: String
    var llmProvider: LLMProvider
    var saveLocation: String
    var autoCopyToClipboard: Bool
    var showQuickOverlay: Bool
    var hideDesktopIcons: Bool
    var hotkeys: HotkeySettings
    var appearanceMode: AppearanceMode
    var launchAtStartup: Bool
    var imageFormat: ImageFormat
    var jpgQuality: Double
    var defaultAnnotationColor: String
    var defaultStrokeWidth: Double

    static var `default`: AppSettings {
        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "~/Desktop"
        let screenshotsPath = (desktopPath as NSString).appendingPathComponent("Screenshots")

        return AppSettings(
            llmApiKey: "",
            llmProvider: .anthropic,
            saveLocation: screenshotsPath,
            autoCopyToClipboard: true,
            showQuickOverlay: true,
            hideDesktopIcons: false,
            hotkeys: .default,
            appearanceMode: .dark,
            launchAtStartup: false,
            imageFormat: .auto,
            jpgQuality: 0.8,
            defaultAnnotationColor: "red",
            defaultStrokeWidth: 3.0
        )
    }
}

enum LLMProvider: String, Codable, CaseIterable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"

    var baseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1"
        case .openai: return "https://api.openai.com/v1"
        }
    }
}

struct HotkeySettings: Codable {
    var areaCapture: String
    var windowCapture: String
    var fullscreenCapture: String

    static var `default`: HotkeySettings {
        HotkeySettings(
            areaCapture: "⌘⇧4",
            windowCapture: "⌘⇧5",
            fullscreenCapture: "⌘⇧3"
        )
    }
}
