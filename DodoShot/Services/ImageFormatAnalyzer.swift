import Foundation
import AppKit
import CoreGraphics
import Vision

/// Service for analyzing images and determining optimal format (PNG vs JPG)
class ImageFormatAnalyzer {
    static let shared = ImageFormatAnalyzer()

    private init() {}

    /// Analyze image and determine optimal format
    /// - Returns: .png for screenshots with text/UI, .jpg for photos/gradients
    func analyzeImage(_ image: NSImage) -> ImageFormat {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .png // Default to PNG if can't analyze
        }

        // Run analysis
        let hasSignificantText = checkForText(cgImage)
        let colorAnalysis = analyzeColorDistribution(cgImage)

        // Decision logic:
        // - If image has significant text -> PNG (better for sharp edges)
        // - If image has flat colors / few unique colors -> PNG (UI screenshots)
        // - If image has many colors / gradients / noise -> JPG (photos)

        if hasSignificantText {
            return .png
        }

        if colorAnalysis.uniqueColorRatio < 0.1 {
            // Few unique colors relative to pixels = UI/flat graphics
            return .png
        }

        if colorAnalysis.hasGradients || colorAnalysis.hasNoise {
            return .jpg
        }

        // Default to PNG for screenshots
        return .png
    }

    /// Check if image contains significant text using Vision
    private func checkForText(_ cgImage: CGImage) -> Bool {
        var hasText = false
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, _ in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                // Consider significant if more than 3 text regions found
                hasText = observations.count > 3
            }
            semaphore.signal()
        }
        request.recognitionLevel = .fast

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        _ = semaphore.wait(timeout: .now() + 1.0) // 1 second timeout
        return hasText
    }

    /// Analyze color distribution to detect gradients, noise, and unique colors
    private func analyzeColorDistribution(_ cgImage: CGImage) -> ColorAnalysis {
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height

        // Sample pixels (not all for performance)
        let sampleSize = min(10000, totalPixels)
        let sampleStep = max(1, totalPixels / sampleSize)

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return ColorAnalysis(uniqueColorRatio: 0.5, hasGradients: false, hasNoise: false)
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        var colorSet = Set<UInt32>()
        var gradientCount = 0
        var noiseCount = 0
        var lastR: UInt8 = 0
        var lastG: UInt8 = 0
        var lastB: UInt8 = 0
        var sampledPixels = 0

        for i in stride(from: 0, to: totalPixels, by: sampleStep) {
            let y = i / width
            let x = i % width
            let offset = y * bytesPerRow + x * bytesPerPixel

            let r = ptr[offset]
            let g = ptr[offset + 1]
            let b = ptr[offset + 2]

            // Quantize colors to reduce uniqueness from slight variations
            let quantizedR = r / 8
            let quantizedG = g / 8
            let quantizedB = b / 8
            let colorKey = UInt32(quantizedR) << 16 | UInt32(quantizedG) << 8 | UInt32(quantizedB)
            colorSet.insert(colorKey)

            // Check for gradients (smooth color transitions)
            if sampledPixels > 0 {
                let diffR = abs(Int(r) - Int(lastR))
                let diffG = abs(Int(g) - Int(lastG))
                let diffB = abs(Int(b) - Int(lastB))
                let totalDiff = diffR + diffG + diffB

                if totalDiff > 5 && totalDiff < 30 {
                    gradientCount += 1
                } else if totalDiff > 50 {
                    noiseCount += 1
                }
            }

            lastR = r
            lastG = g
            lastB = b
            sampledPixels += 1
        }

        let uniqueColorRatio = Double(colorSet.count) / Double(sampledPixels)
        let hasGradients = Double(gradientCount) / Double(sampledPixels) > 0.3
        let hasNoise = Double(noiseCount) / Double(sampledPixels) > 0.2

        return ColorAnalysis(
            uniqueColorRatio: uniqueColorRatio,
            hasGradients: hasGradients,
            hasNoise: hasNoise
        )
    }

    struct ColorAnalysis {
        let uniqueColorRatio: Double
        let hasGradients: Bool
        let hasNoise: Bool
    }

    /// Save image with appropriate format based on settings
    func saveImage(_ image: NSImage, to url: URL, format: ImageFormat, jpgQuality: Double = 0.8) -> URL? {
        let actualFormat: ImageFormat
        if format == .auto {
            actualFormat = analyzeImage(image)
        } else {
            actualFormat = format
        }

        // Modify URL extension based on format
        let finalURL: URL
        if actualFormat == .jpg {
            finalURL = url.deletingPathExtension().appendingPathExtension("jpg")
        } else {
            finalURL = url.deletingPathExtension().appendingPathExtension("png")
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let imageData: Data?
        if actualFormat == .jpg {
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: jpgQuality])
        } else {
            imageData = bitmapRep.representation(using: .png, properties: [:])
        }

        guard let data = imageData else { return nil }

        do {
            try data.write(to: finalURL)
            return finalURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
}
