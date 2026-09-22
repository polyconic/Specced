import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum FixError: LocalizedError {
    case unreadable
    case unwritable
    case overLimit

    var errorDescription: String? {
        switch self {
        case .unreadable: "The original couldn't be read."
        case .unwritable: "The file couldn't be written."
        case .overLimit: "It can't get under the size limit without dropping below the platform minimum."
        }
    }
}

enum FileFix {
    static func export(_ facts: ImageFacts, _ plan: FixPlan, to url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(facts.url as CFURL, nil) else { throw FixError.unreadable }
        var image = try fullImage(source, facts)

        if let crop = plan.crop {
            let w = Double(image.width), h = Double(image.height)
            let rect = CGRect(x: (crop.minX * w).rounded(), y: (crop.minY * h).rounded(),
                              width: (crop.width * w).rounded(), height: (crop.height * h).rounded())
            image = image.cropping(to: rect.intersection(CGRect(x: 0, y: 0, width: w, height: h))) ?? image
        }

        if let dpi = plan.tiffDPI {
            let props: [CFString: Any] = [
                kCGImagePropertyDPIWidth: dpi,
                kCGImagePropertyDPIHeight: dpi,
                kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 5],
            ]
            guard let data = encode(image, .tiff, props) else { throw FixError.unwritable }
            try data.write(to: url, options: .atomic)
            return
        }

        let target = plan.size ?? (w: image.width, h: image.height)
        var scale = 1.0
        while true {
            let w = Int((Double(target.w) * scale).rounded()), h = Int((Double(target.h) * scale).rounded())
            if min(w, h) < 16 || plan.minSide.map({ Double(min(w, h)) < $0 }) == true { throw FixError.overLimit }
            guard let rendered = render(image, w, h, alpha: plan.png && facts.hasAlpha) else { throw FixError.unwritable }
            if plan.png {
                guard let data = encode(rendered, .png, [:]) else { throw FixError.unwritable }
                if plan.maxBytes.map({ data.count <= $0 }) ?? true {
                    try data.write(to: url, options: .atomic)
                    return
                }
            } else {
                for quality in stride(from: 0.95, through: 0.7, by: -0.05) {
                    guard let data = encode(rendered, .jpeg, [kCGImageDestinationLossyCompressionQuality: quality]) else {
                        throw FixError.unwritable
                    }
                    if plan.maxBytes.map({ data.count <= $0 }) ?? true {
                        try data.write(to: url, options: .atomic)
                        return
                    }
                }
            }
            scale *= 0.9
        }
    }

    private static func fullImage(_ source: CGImageSource, _ facts: ImageFacts) throws -> CGImage {
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = props?[kCGImagePropertyOrientation] as? Int ?? 1
        if orientation == 1, let image = CGImageSourceCreateImageAtIndex(source, 0, nil) { return image }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(facts.width, facts.height),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw FixError.unreadable
        }
        return image
    }

    private static func render(_ image: CGImage, _ w: Int, _ h: Int, alpha: Bool) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return context.makeImage()
    }

    private static func encode(_ image: CGImage, _ type: UTType, _ props: [CFString: Any]) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, props as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
