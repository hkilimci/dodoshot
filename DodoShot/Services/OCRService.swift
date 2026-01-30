import Foundation
import Vision
import AppKit

/// Service for performing OCR on images using Apple's Vision framework
class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Perform OCR on an image and return extracted text
    func extractText(from image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        // Create a request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Create the text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    completion(.failure(OCRError.noTextFound))
                }
                return
            }

            // Extract text from observations
            let extractedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            DispatchQueue.main.async {
                if extractedText.isEmpty {
                    completion(.failure(OCRError.noTextFound))
                } else {
                    completion(.success(extractedText))
                }
            }
        }

        // Configure for accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Perform the request
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Copy extracted text to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process image for text extraction"
        case .noTextFound:
            return "No text found in image"
        }
    }
}
