import SwiftUI
import UIKit

/// Swipe left/right through the cards of the list you came from.
struct CardPagerView: View {
    let route: CardRoute
    @State private var current: String?

    private var index: Int { route.cards.firstIndex { $0.id == current } ?? route.index }
    private var card: Card { route.cards[index] }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(route.cards) { c in
                    CardDetailView(card: c)
                        .containerRelativeFrame(.horizontal)
                        .id(c.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
        .background(Theme.paper)
        .navigationTitle(card.yearText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(card.yearText).font(.headline)
                    Text("\(index + 1) of \(route.cards.count)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: card.shareText) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .onAppear { if current == nil { current = route.cards[route.index].id } }
        .sensoryFeedback(.selection, trigger: current)
    }
}

struct CardDetailView: View {
    let card: Card
    @State private var viewer: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(card.yearText) · \(card.folder)\(card.sub.map { $0.isEmpty ? "" : " / \($0)" } ?? "")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(card.title)
                        .font(.serif(.title2, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(card.fileName)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.ink2)
                        .textSelection(.enabled)
                }

                if card.images.isEmpty {
                    Label("The scan for this card is lost — the file is zero bytes.", systemImage: "doc.questionmark")
                        .font(.serif(.callout))
                        .foregroundStyle(Theme.ink2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 10))
                } else {
                    PageStrip(images: card.images, cover: card.coverIndex) { viewer = $0 }
                }

                if !card.flag.isEmpty {
                    Label(card.flag, systemImage: "exclamationmark.triangle.fill")
                        .font(.serif(.callout))
                        .foregroundStyle(Theme.warn)
                }

                ForEach(card.fields, id: \.self) { f in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.key.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.ink2)
                        Text(f.value)
                            .font(.serif(.body))
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }
                }
                ForEach(card.paragraphs, id: \.self) { p in
                    Text(p)
                        .font(.serif(.callout))
                        .italic()
                        .foregroundStyle(Theme.ink2)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(item: Binding(get: { viewer.map(ViewerStart.init) }, set: { viewer = $0?.page })) { start in
            PageViewer(images: card.images, start: start.page)
        }
    }

    private struct ViewerStart: Identifiable {
        let page: Int
        var id: Int { page }
    }
}

/// The card's pages side by side, cover first; tap one to open it full screen.
private struct PageStrip: View {
    let images: [String]
    let cover: Int
    let open: (Int) -> Void

    private var ordered: [Int] {
        let c = min(max(cover, 0), images.count - 1)
        return [c] + images.indices.filter { $0 != c }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ordered, id: \.self) { i in
                    Button { open(i) } label: {
                        ScanImage(file: images[i], maxPixel: 1100, contentMode: .fit)
                            .frame(height: 380)
                            .frame(minWidth: 200)
                            .background(Theme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            .overlay(alignment: .bottomLeading) {
                                Text("p\(i + 1)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(6)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

/// Full-screen pages with pinch and double-tap zoom.
struct PageViewer: View {
    let images: [String]
    let start: Int
    @State private var page = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(images.indices, id: \.self) { i in
                    ZoomablePage(file: images[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
        .statusBarHidden()
        .onAppear { page = start }
    }
}

private struct ZoomablePage: View {
    let file: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ZoomableImage(image: image)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: file) { image = await ImageLoader.shared.image(file, maxPixel: 3000) }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.maximumZoomScale = 5
        sv.minimumZoomScale = 1
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.backgroundColor = .clear
        sv.contentInsetAdjustmentBehavior = .never
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.frame = sv.bounds
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sv.addSubview(iv)
        context.coordinator.imageView = iv
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        sv.addGestureRecognizer(tap)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView else { return }
            if sv.zoomScale > 1 {
                sv.setZoomScale(1, animated: true)
            } else {
                let p = g.location(in: imageView)
                let size = CGSize(width: sv.bounds.width / 2.5, height: sv.bounds.height / 2.5)
                sv.zoom(to: CGRect(origin: CGPoint(x: p.x - size.width / 2, y: p.y - size.height / 2), size: size), animated: true)
            }
        }
    }
}

extension Card {
    var shareText: String {
        var lines = ["\(title) (\(yearText))", "\(folder)\(sub.map { $0.isEmpty ? "" : " / \($0)" } ?? "")", ""]
        lines += fields.map { "\($0.key): \($0.value)" }
        lines += paragraphs
        return lines.joined(separator: "\n")
    }
}
