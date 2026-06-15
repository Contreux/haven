import UIKit

enum ImageScaler {
    /// Downscale to maxDimension and JPEG-compress. Returns the original on failure.
    static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.6) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
