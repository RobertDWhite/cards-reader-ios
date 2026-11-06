import SwiftUI
import UIKit
import ImageIO

/// Loads card scans through a large disk URLCache and keeps decoded, downsampled
/// bitmaps in memory. Full scans are ~1300px JPEGs; grid tiles only need a fraction.
actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let memory = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 2 << 30)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
        memory.totalCostLimit = 160 << 20
    }

    func image(_ file: String, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(file)@\(Int(maxPixel))" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        if let task = inflight[key as String] { return await task.value }
        let url = Server.image(file)
        let session = self.session
        let task = Task<UIImage?, Never> {
            guard let (data, resp) = try? await session.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode ?? 200 < 400 else { return nil }
            return Self.downsample(data, maxPixel: maxPixel)
        }
        inflight[key as String] = task
        let img = await task.value
        inflight[key as String] = nil
        if let img {
            let cost = Int(img.size.width * img.size.height * img.scale * img.scale * 4)
            memory.setObject(img, forKey: key, cost: cost)
        }
        return img
    }

    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let opts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, opts) else { return nil }
        let thumbOpts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct ScanImage: View {
    let file: String
    var maxPixel: CGFloat = 600
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if failed {
                Image(systemName: "photo").foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: file) {
            failed = false
            let img = await ImageLoader.shared.image(file, maxPixel: maxPixel)
            withAnimation(.easeOut(duration: 0.2)) {
                image = img
                failed = img == nil
            }
        }
    }
}
