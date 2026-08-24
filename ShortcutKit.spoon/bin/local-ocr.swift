import AppKit
import Foundation
import Vision

enum LocalOCRError: LocalizedError {
    case usage
    case unreadableImage(String)
    case noText

    var errorDescription: String? {
        switch self {
        case .usage: return "Usage: local-ocr <image-path> | --self-test"
        case .unreadableImage(let path): return "Cannot read image: \(path)"
        case .noText: return "No text recognized"
        }
    }
}

struct RecognizedLine {
    let text: String
    let box: CGRect
}

func recognizeText(at path: String) throws -> String {
    guard let image = NSImage(contentsOfFile: path),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw LocalOCRError.unreadableImage(path)
    }

    var lines: [RecognizedLine] = []
    var requestError: Error?
    let request = VNRecognizeTextRequest { request, error in
        if let error { requestError = error; return }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        lines = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(text: candidate.string, box: observation.boundingBox)
        }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.automaticallyDetectsLanguage = true
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "es-ES"]
    request.minimumTextHeight = 0.008

    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
    if let requestError { throw requestError }

    lines.sort { lhs, rhs in
        let verticalDifference = abs(lhs.box.midY - rhs.box.midY)
        let sameLine = verticalDifference < max(lhs.box.height, rhs.box.height) * 0.5
        return sameLine ? lhs.box.minX < rhs.box.minX : lhs.box.midY > rhs.box.midY
    }
    let text = lines.map(\.text).joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw LocalOCRError.noText }
    return text
}

func makeSelfTestImage(at path: String) throws {
    let size = NSSize(width: 1000, height: 260)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 54, weight: .semibold),
        .foregroundColor: NSColor.black,
    ]
    NSString(string: "本地 OCR 测试 123\nTexto español ABC").draw(
        in: NSRect(x: 40, y: 45, width: 920, height: 180),
        withAttributes: attributes
    )
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw LocalOCRError.unreadableImage(path)
    }
    try png.write(to: URL(fileURLWithPath: path), options: .atomic)
}

do {
    guard CommandLine.arguments.count == 2 else { throw LocalOCRError.usage }
    let argument = CommandLine.arguments[1]
    if argument == "--self-test" {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-ocr-self-test-\(UUID().uuidString).png").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        try makeSelfTestImage(at: path)
        let result = try recognizeText(at: path)
        guard result.contains("OCR"), result.contains("123"),
              result.localizedCaseInsensitiveContains("Texto") else {
            fputs("Self-test recognized unexpected text:\n\(result)\n", stderr)
            exit(2)
        }
        print(result)
    } else {
        print(try recognizeText(at: argument))
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
