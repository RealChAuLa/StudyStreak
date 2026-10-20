import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ProfilePhotoError: LocalizedError {
    case unsupported, tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupported: "That photo couldn’t be opened. Please choose another image."
        case .tooLarge: "That photo is too large. Please choose a smaller image."
        }
    }
}

nonisolated enum ProfilePhotoProcessor {
    static let maximumBytes = 150 * 1024

    static func compress(_ data: Data) throws -> Data {
        guard data.count <= 20 * 1024 * 1024 else { throw ProfilePhotoError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ProfilePhotoError.unsupported
        }
        // Decode only a thumbnail, applying EXIF orientation before cropping.
        for dimension in [512, 384, 256] {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: dimension
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw ProfilePhotoError.unsupported
            }
            let side = min(thumbnail.width, thumbnail.height)
            let crop = CGRect(x: CGFloat((thumbnail.width - side) / 2), y: CGFloat((thumbnail.height - side) / 2), width: CGFloat(side), height: CGFloat(side))
            guard let square = thumbnail.cropping(to: crop),
                  let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw ProfilePhotoError.unsupported
            }
            let bounds = CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side))
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            context.draw(square, in: bounds)
            guard let opaqueImage = context.makeImage() else { throw ProfilePhotoError.unsupported }
            for quality in [0.82, 0.7, 0.55, 0.4] {
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
                    throw ProfilePhotoError.unsupported
                }
                // Re-encoding pixels without source metadata removes GPS/EXIF data.
                CGImageDestinationAddImage(destination, opaqueImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                if CGImageDestinationFinalize(destination), output.length <= maximumBytes {
                    return output as Data
                }
            }
        }
        throw ProfilePhotoError.tooLarge
    }
}
